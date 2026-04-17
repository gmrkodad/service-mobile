from datetime import timedelta
from decimal import Decimal, InvalidOperation
from typing import Optional

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import login, logout
from django.contrib.auth.decorators import login_required
from django.db.models import Q
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone

from apps.accounts.models import OtpCode, SupportTicket, User
from apps.bookings.models import Booking, Review
from apps.services.models import Category, ProviderServicePrice, Service

ALLOWED_CONSOLE_ROLES = {User.Roles.ADMIN, User.Roles.SUPPORT}
ALLOWED_TICKET_STATUSES = {
    SupportTicket.Statuses.OPEN,
    SupportTicket.Statuses.IN_PROGRESS,
    SupportTicket.Statuses.RESOLVED,
    SupportTicket.Statuses.CLOSED,
}
ALLOWED_BOOKING_STATUSES = {value for value, _ in Booking.Statuses.choices}
ALLOWED_USER_ROLES = {
    User.Roles.CUSTOMER,
    User.Roles.PROVIDER,
    User.Roles.SUPPORT,
    User.Roles.ADMIN,
}
ALLOWED_GENDERS = {
    User.Genders.MALE,
    User.Genders.FEMALE,
    User.Genders.OTHER,
}


def _is_console_user(user) -> bool:
    return bool(
        user
        and user.is_authenticated
        and user.is_active
        and user.role in ALLOWED_CONSOLE_ROLES
    )


def _role_home(user) -> str:
    if user.role == User.Roles.SUPPORT:
        return "console_support_dashboard"
    return "console_admin_dashboard"


def _issue_otp(phone: str) -> str:
    code = "1234"
    OtpCode.objects.create(phone=phone, purpose=OtpCode.Purposes.LOGIN, code=code)
    return code


def _consume_otp(phone: str, otp: str) -> bool:
    if not phone or not otp:
        return False
    if otp == "1234":
        return True
    window_start = timezone.now() - timedelta(minutes=10)
    row = (
        OtpCode.objects.filter(
            phone=phone,
            purpose=OtpCode.Purposes.LOGIN,
            code=otp,
            created_at__gte=window_start,
        )
        .order_by("-created_at")
        .first()
    )
    if row is None:
        return False
    row.delete()
    return True


def _is_true(value: str) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def _parse_money(value: str) -> Optional[Decimal]:
    raw = str(value or "").strip()
    if not raw:
        return None
    try:
        parsed = Decimal(raw)
    except InvalidOperation:
        return None
    if parsed < 0:
        return None
    return parsed.quantize(Decimal("0.01"))


def _ticket_queryset():
    return SupportTicket.objects.select_related(
        "requester",
        "booking",
        "booking__service",
        "booking__provider",
        "booking__customer",
    )


def _require_console_user(request):
    if not _is_console_user(request.user):
        logout(request)
        messages.error(request, "Please login with Admin or Support account.")
        return False
    return True


def _require_admin_user(request):
    if not _require_console_user(request):
        return redirect("console_login")
    if request.user.role != User.Roles.ADMIN:
        messages.error(request, "Admin access required for this page.")
        return redirect("console_support_dashboard")
    return None


def _require_support_or_admin(request):
    if not _require_console_user(request):
        return redirect("console_login")
    return None


def _support_stats():
    base = _ticket_queryset().order_by("-updated_at")
    return {
        "ticket_statuses": SupportTicket.Statuses.choices,
        "open_count": base.filter(status=SupportTicket.Statuses.OPEN).count(),
        "in_progress_count": base.filter(
            status=SupportTicket.Statuses.IN_PROGRESS
        ).count(),
        "resolved_count": base.filter(status=SupportTicket.Statuses.RESOLVED).count(),
        "closed_count": base.filter(status=SupportTicket.Statuses.CLOSED).count(),
        "open_tickets": base.filter(status=SupportTicket.Statuses.OPEN)[:8],
        "in_progress_tickets": base.filter(
            status=SupportTicket.Statuses.IN_PROGRESS
        )[:8],
        "resolved_tickets": base.filter(status=SupportTicket.Statuses.RESOLVED)[:8],
        "closed_tickets": base.filter(status=SupportTicket.Statuses.CLOSED)[:8],
    }


def console_home_view(request):
    if _is_console_user(request.user):
        return redirect(_role_home(request.user))
    return redirect("console_login")


def console_login_view(request):
    if _is_console_user(request.user):
        return redirect(_role_home(request.user))

    if request.method == "POST":
        action = (request.POST.get("action") or "").strip().lower()
        phone = (request.POST.get("phone") or "").strip()
        otp = (request.POST.get("otp") or "").strip()
        user = User.objects.filter(phone=phone, is_active=True).first()

        if action == "send":
            if user is None or user.role not in ALLOWED_CONSOLE_ROLES:
                messages.error(request, "Account not allowed for web console.")
            else:
                code = _issue_otp(phone)
                if settings.DEBUG:
                    messages.success(request, f"OTP sent. Dev OTP: {code}")
                else:
                    messages.success(request, "OTP sent.")
            return render(request, "webconsole/login.html", {"prefill_phone": phone})

        if action == "verify":
            if user is None or user.role not in ALLOWED_CONSOLE_ROLES:
                messages.error(request, "Account not allowed for web console.")
            elif not _consume_otp(phone, otp):
                messages.error(request, "Invalid or expired OTP.")
            else:
                login(request, user, backend="django.contrib.auth.backends.ModelBackend")
                return redirect(_role_home(user))
            return render(request, "webconsole/login.html", {"prefill_phone": phone})

        messages.error(request, "Invalid request.")

    return render(request, "webconsole/login.html")


@login_required(login_url="console_login")
def console_logout_view(request):
    logout(request)
    return redirect("console_login")


@login_required(login_url="console_login")
def admin_dashboard_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard

    users_total = User.objects.count()
    customers_total = User.objects.filter(role=User.Roles.CUSTOMER).count()
    providers_total = User.objects.filter(role=User.Roles.PROVIDER).count()
    support_total = User.objects.filter(role=User.Roles.SUPPORT).count()
    bookings_total = Booking.objects.count()
    bookings_open = Booking.objects.filter(
        status__in=[
            Booking.Statuses.PENDING,
            Booking.Statuses.ASSIGNED,
            Booking.Statuses.ACCEPTED,
            Booking.Statuses.IN_PROGRESS,
        ]
    ).count()
    tickets_open = SupportTicket.objects.filter(
        status__in=[SupportTicket.Statuses.OPEN, SupportTicket.Statuses.IN_PROGRESS]
    ).count()

    context = {
        "console_role": "Admin Console",
        "users_total": users_total,
        "customers_total": customers_total,
        "providers_total": providers_total,
        "support_total": support_total,
        "services_total": Service.objects.count(),
        "categories_total": Category.objects.count(),
        "bookings_total": bookings_total,
        "bookings_open": bookings_open,
        "tickets_open": tickets_open,
        "recent_users": User.objects.order_by("-date_joined")[:12],
        "recent_bookings": Booking.objects.select_related(
            "service",
            "customer",
            "provider",
        ).order_by("-created_at")[:12],
        "recent_tickets": _ticket_queryset().order_by("-updated_at")[:15],
        "ticket_statuses": SupportTicket.Statuses.choices,
    }
    return render(request, "webconsole/admin_dashboard.html", context)


@login_required(login_url="console_login")
def admin_users_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard

    if request.method == "POST":
        action = (request.POST.get("action") or "").strip()
        if action == "create_user":
            role = (request.POST.get("role") or User.Roles.CUSTOMER).strip().upper()
            full_name = (request.POST.get("full_name") or "").strip()
            email = (request.POST.get("email") or "").strip()
            phone = (request.POST.get("phone") or "").strip()
            gender = (
                request.POST.get("gender") or User.Genders.OTHER
            ).strip().upper()
            city = (request.POST.get("city") or "").strip()
            service_ids = request.POST.getlist("services")

            if role not in ALLOWED_USER_ROLES:
                messages.error(request, "Invalid role.")
            elif not full_name or not phone:
                messages.error(request, "Name and phone are required.")
            elif User.objects.filter(phone=phone).exists():
                messages.error(request, "User with this phone already exists.")
            elif gender not in ALLOWED_GENDERS:
                messages.error(request, "Invalid gender.")
            else:
                user = User.objects.create_user(
                    phone=phone,
                    full_name=full_name,
                    email=email,
                    gender=gender,
                    role=role,
                    city=city,
                    is_active=True,
                    is_staff=role == User.Roles.ADMIN,
                    is_superuser=role == User.Roles.ADMIN,
                )
                if role == User.Roles.PROVIDER:
                    valid_ids = [int(v) for v in service_ids if str(v).isdigit()]
                    for service in Service.objects.filter(id__in=valid_ids):
                        ProviderServicePrice.objects.get_or_create(
                            provider=user,
                            service=service,
                            defaults={"price": service.base_price},
                        )
                messages.success(request, f"User created: {user.display_name}")
            return redirect("console_admin_users")

        if action == "toggle_user":
            user_id = request.POST.get("user_id")
            user = User.objects.filter(id=user_id).first()
            if user is None:
                messages.error(request, "User not found.")
            elif user.id == request.user.id:
                messages.error(request, "You cannot disable your own account.")
            else:
                user.is_active = not user.is_active
                user.save(update_fields=["is_active"])
                messages.success(request, f"Updated active status for {user.display_name}.")
            return redirect("console_admin_users")

        if action == "delete_user":
            user_id = request.POST.get("user_id")
            user = User.objects.filter(id=user_id).first()
            if user is None:
                messages.error(request, "User not found.")
            elif user.id == request.user.id:
                messages.error(request, "You cannot delete your own account.")
            else:
                label = user.display_name
                user.delete()
                messages.success(request, f"Deleted user {label}.")
            return redirect("console_admin_users")

        if action == "update_provider_services":
            user_id = request.POST.get("user_id")
            provider = User.objects.filter(id=user_id, role=User.Roles.PROVIDER).first()
            if provider is None:
                messages.error(request, "Provider not found.")
                return redirect("console_admin_users")
            service_ids = [int(v) for v in request.POST.getlist("services") if str(v).isdigit()]
            ProviderServicePrice.objects.filter(provider=provider).exclude(
                service_id__in=service_ids
            ).delete()
            for service in Service.objects.filter(id__in=service_ids):
                ProviderServicePrice.objects.get_or_create(
                    provider=provider,
                    service=service,
                    defaults={"price": service.base_price},
                )
            messages.success(
                request,
                f"Updated services for provider {provider.display_name}.",
            )
            return redirect("console_admin_users")

        messages.error(request, "Unsupported action.")
        return redirect("console_admin_users")

    role_filter = (request.GET.get("role") or "").strip().upper()
    query = (request.GET.get("q") or "").strip()
    users = User.objects.prefetch_related("provider_service_prices__service").order_by(
        "-date_joined"
    )
    if role_filter in ALLOWED_USER_ROLES:
        users = users.filter(role=role_filter)
    if query:
        users = users.filter(
            Q(full_name__icontains=query)
            | Q(email__icontains=query)
            | Q(phone__icontains=query)
        )
    users = list(users[:400])
    for user in users:
        user.selected_service_ids = [
            row.service_id for row in user.provider_service_prices.all()
        ]

    context = {
        "console_role": "Admin Console",
        "users": users,
        "role_filter": role_filter,
        "query": query,
        "roles": User.Roles.choices,
        "genders": User.Genders.choices,
        "all_services": Service.objects.select_related("category").order_by(
            "category__name", "name"
        ),
    }
    return render(request, "webconsole/admin_users.html", context)


@login_required(login_url="console_login")
def admin_categories_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard

    if request.method == "POST":
        action = (request.POST.get("action") or "").strip()
        if action == "create_category":
            name = (request.POST.get("name") or "").strip()
            if not name:
                messages.error(request, "Category name is required.")
            elif Category.objects.filter(name__iexact=name).exists():
                messages.error(request, "Category already exists.")
            else:
                Category.objects.create(
                    name=name,
                    description=(request.POST.get("description") or "").strip(),
                    image_url=(request.POST.get("image_url") or "").strip(),
                    is_active=_is_true(request.POST.get("is_active")),
                )
                messages.success(request, f"Category created: {name}")
            return redirect("console_admin_categories")

        if action == "update_category":
            category = Category.objects.filter(id=request.POST.get("category_id")).first()
            if category is None:
                messages.error(request, "Category not found.")
                return redirect("console_admin_categories")
            name = (request.POST.get("name") or "").strip()
            if not name:
                messages.error(request, "Category name is required.")
                return redirect("console_admin_categories")
            category.name = name
            category.description = (request.POST.get("description") or "").strip()
            category.image_url = (request.POST.get("image_url") or "").strip()
            category.is_active = _is_true(request.POST.get("is_active"))
            category.save()
            messages.success(request, f"Category updated: {category.name}")
            return redirect("console_admin_categories")

        if action == "delete_category":
            category = Category.objects.filter(id=request.POST.get("category_id")).first()
            if category is None:
                messages.error(request, "Category not found.")
            else:
                label = category.name
                category.delete()
                messages.success(request, f"Category deleted: {label}")
            return redirect("console_admin_categories")

        messages.error(request, "Unsupported action.")
        return redirect("console_admin_categories")

    context = {
        "console_role": "Admin Console",
        "categories": Category.objects.order_by("name"),
    }
    return render(request, "webconsole/admin_categories.html", context)


@login_required(login_url="console_login")
def admin_services_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard

    if request.method == "POST":
        action = (request.POST.get("action") or "").strip()
        if action == "create_service":
            name = (request.POST.get("name") or "").strip()
            category_id = request.POST.get("category_id")
            base_price = _parse_money(request.POST.get("base_price"))
            starts_from = _parse_money(request.POST.get("starts_from"))
            category = Category.objects.filter(id=category_id).first()
            if category is None:
                messages.error(request, "Valid category is required.")
            elif not name:
                messages.error(request, "Service name is required.")
            elif base_price is None:
                messages.error(request, "Valid base price is required.")
            else:
                Service.objects.create(
                    category=category,
                    name=name,
                    description=(request.POST.get("description") or "").strip(),
                    image_url=(request.POST.get("image_url") or "").strip(),
                    base_price=base_price,
                    starts_from=starts_from,
                    is_active=_is_true(request.POST.get("is_active")),
                )
                messages.success(request, f"Service created: {name}")
            return redirect("console_admin_services")

        if action == "update_service":
            service = Service.objects.filter(id=request.POST.get("service_id")).first()
            if service is None:
                messages.error(request, "Service not found.")
                return redirect("console_admin_services")
            category = Category.objects.filter(id=request.POST.get("category_id")).first()
            base_price = _parse_money(request.POST.get("base_price"))
            starts_from = _parse_money(request.POST.get("starts_from"))
            name = (request.POST.get("name") or "").strip()
            if category is None:
                messages.error(request, "Valid category is required.")
                return redirect("console_admin_services")
            if not name:
                messages.error(request, "Service name is required.")
                return redirect("console_admin_services")
            if base_price is None:
                messages.error(request, "Valid base price is required.")
                return redirect("console_admin_services")
            service.category = category
            service.name = name
            service.description = (request.POST.get("description") or "").strip()
            service.image_url = (request.POST.get("image_url") or "").strip()
            service.base_price = base_price
            service.starts_from = starts_from
            service.is_active = _is_true(request.POST.get("is_active"))
            service.save()
            messages.success(request, f"Service updated: {service.name}")
            return redirect("console_admin_services")

        if action == "delete_service":
            service = Service.objects.filter(id=request.POST.get("service_id")).first()
            if service is None:
                messages.error(request, "Service not found.")
            else:
                label = service.name
                service.delete()
                messages.success(request, f"Service deleted: {label}")
            return redirect("console_admin_services")

        messages.error(request, "Unsupported action.")
        return redirect("console_admin_services")

    category_filter = request.GET.get("category") or ""
    query = (request.GET.get("q") or "").strip()
    services = Service.objects.select_related("category").order_by("category__name", "name")
    if str(category_filter).isdigit():
        services = services.filter(category_id=int(category_filter))
    if query:
        services = services.filter(Q(name__icontains=query) | Q(description__icontains=query))

    context = {
        "console_role": "Admin Console",
        "services": services[:500],
        "categories": Category.objects.order_by("name"),
        "category_filter": category_filter,
        "query": query,
    }
    return render(request, "webconsole/admin_services.html", context)


@login_required(login_url="console_login")
def admin_bookings_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard

    if request.method == "POST":
        action = (request.POST.get("action") or "").strip()
        booking = Booking.objects.filter(id=request.POST.get("booking_id")).first()
        if booking is None:
            messages.error(request, "Booking not found.")
            return redirect("console_admin_bookings")

        if action == "assign_provider":
            provider = User.objects.filter(
                id=request.POST.get("provider_id"),
                role=User.Roles.PROVIDER,
                is_active=True,
            ).first()
            if provider is None:
                messages.error(request, "Valid provider required.")
            else:
                booking.provider = provider
                booking.status = Booking.Statuses.ASSIGNED
                booking.save(update_fields=["provider", "status"])
                messages.success(
                    request,
                    f"Provider {provider.display_name} assigned to booking #{booking.id}.",
                )
            return redirect("console_admin_bookings")

        if action == "update_status":
            status = (request.POST.get("status") or "").strip().upper()
            if status not in ALLOWED_BOOKING_STATUSES:
                messages.error(request, "Invalid booking status.")
            else:
                booking.status = status
                booking.save(update_fields=["status"])
                messages.success(
                    request,
                    f"Booking #{booking.id} status updated to {status}.",
                )
            return redirect("console_admin_bookings")

        messages.error(request, "Unsupported action.")
        return redirect("console_admin_bookings")

    status_filter = (request.GET.get("status") or "").strip().upper()
    query = (request.GET.get("q") or "").strip()
    bookings = Booking.objects.select_related("service", "customer", "provider").order_by(
        "-created_at"
    )
    if status_filter in ALLOWED_BOOKING_STATUSES:
        bookings = bookings.filter(status=status_filter)
    if query:
        q = (
            Q(service__name__icontains=query)
            | Q(customer__full_name__icontains=query)
            | Q(customer__phone__icontains=query)
            | Q(provider__full_name__icontains=query)
            | Q(provider__phone__icontains=query)
        )
        if query.isdigit():
            q |= Q(id=int(query))
        bookings = bookings.filter(q)

    context = {
        "console_role": "Admin Console",
        "bookings": bookings[:400],
        "providers": User.objects.filter(
            role=User.Roles.PROVIDER,
            is_active=True,
        ).order_by("full_name", "phone"),
        "status_choices": Booking.Statuses.choices,
        "status_filter": status_filter,
        "query": query,
    }
    return render(request, "webconsole/admin_bookings.html", context)


@login_required(login_url="console_login")
def admin_tickets_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard
    return support_tickets_view(request, template_name="webconsole/admin_tickets.html")


@login_required(login_url="console_login")
def admin_reviews_view(request):
    guard = _require_admin_user(request)
    if guard:
        return guard

    query = (request.GET.get("q") or "").strip()
    reviews = Review.objects.select_related("booking", "provider", "author").order_by(
        "-created_at"
    )
    if query:
        q = (
            Q(provider__full_name__icontains=query)
            | Q(provider__phone__icontains=query)
            | Q(author__full_name__icontains=query)
            | Q(comment__icontains=query)
        )
        if query.isdigit():
            q |= Q(booking__id=int(query))
        reviews = reviews.filter(q)

    context = {
        "console_role": "Admin Console",
        "reviews": reviews[:300],
        "query": query,
    }
    return render(request, "webconsole/admin_reviews.html", context)


@login_required(login_url="console_login")
def support_dashboard_view(request):
    guard = _require_support_or_admin(request)
    if guard:
        return guard
    context = {"console_role": "Support Console", **_support_stats()}
    return render(request, "webconsole/support_dashboard.html", context)


@login_required(login_url="console_login")
def support_tickets_view(request, template_name="webconsole/support_tickets.html"):
    guard = _require_support_or_admin(request)
    if guard:
        return guard

    if request.method == "POST":
        status = (request.POST.get("status") or "").strip().upper()
        ticket = get_object_or_404(SupportTicket, id=request.POST.get("ticket_id"))
        if status not in ALLOWED_TICKET_STATUSES:
            messages.error(request, "Invalid ticket status selected.")
        else:
            ticket.status = status
            ticket.save(update_fields=["status", "updated_at"])
            messages.success(request, f"Ticket #{ticket.id} updated to {status}.")
        return redirect(request.POST.get("next") or request.path)

    status = (request.GET.get("status") or "").strip().upper()
    query = (request.GET.get("q") or "").strip()
    tickets = _ticket_queryset().order_by("-updated_at")
    if status in ALLOWED_TICKET_STATUSES:
        tickets = tickets.filter(status=status)
    if query:
        q = (
            Q(issue_type__icontains=query)
            | Q(message__icontains=query)
            | Q(requester__full_name__icontains=query)
            | Q(requester__phone__icontains=query)
        )
        if query.isdigit():
            q |= Q(id=int(query)) | Q(booking__id=int(query))
        tickets = tickets.filter(q)

    context = {
        "console_role": "Support Console",
        "selected_status": status,
        "query": query,
        "tickets": tickets[:300],
        **_support_stats(),
    }
    return render(request, template_name, context)


@login_required(login_url="console_login")
def ticket_status_update_view(request, ticket_id: int):
    if request.method != "POST":
        return redirect("console_home")
    guard = _require_support_or_admin(request)
    if guard:
        return guard

    status = (request.POST.get("status") or "").strip().upper()
    if status not in ALLOWED_TICKET_STATUSES:
        messages.error(request, "Invalid ticket status selected.")
        return redirect(request.POST.get("next") or "console_home")

    ticket = get_object_or_404(SupportTicket, id=ticket_id)
    ticket.status = status
    ticket.save(update_fields=["status", "updated_at"])
    messages.success(request, f"Ticket #{ticket.id} updated to {status}.")
    return redirect(request.POST.get("next") or "console_home")
