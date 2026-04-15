from django.contrib.auth import get_user_model
from django.db.models import Q
from django.db.models import Avg
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.bookings.models import Booking
from apps.services.models import ProviderServicePrice, Service

from .models import DeviceToken, Notification, OtpCode, SupportTicket
from .permissions import IsAdminRole, IsProviderRole
from .push import create_notification
from .serializers import (
    AdminUserSerializer,
    NotificationSerializer,
    ProviderServicePriceSerializer,
    SupportTicketSerializer,
    UserProfileSerializer,
    token_pair_for_user,
)

User = get_user_model()


def _issue_otp(phone: str, purpose: str) -> str:
    code = "1234"
    OtpCode.objects.create(phone=phone, purpose=purpose, code=code)
    return code


class OtpSendView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        if not phone:
            return Response({"detail": "phone is required"}, status=400)
        code = _issue_otp(phone, OtpCode.Purposes.LOGIN)
        return Response({"message": "OTP sent", "debug_otp": code})


class OtpSendSignupView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        code = _issue_otp(phone, OtpCode.Purposes.SIGNUP)
        return Response({"message": "Signup OTP sent", "debug_otp": code})


class OtpVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
        otp = request.data.get("otp", "").strip()
        if not phone:
            return Response({"detail": "phone is required"}, status=400)
        otp_row = OtpCode.objects.filter(
            phone=phone,
            purpose=OtpCode.Purposes.LOGIN,
            code=otp,
        ).first()
        if not otp_row:
            return Response({"detail": "Invalid OTP"}, status=400)
        user = User.objects.filter(phone=phone).first()
        if not user:
            full_name = request.data.get("full_name", "").strip()
            email = request.data.get("email", "").strip()
            gender = request.data.get("gender", "").strip().upper()
            role = request.data.get("role", User.Roles.CUSTOMER).strip().upper()
            city = request.data.get("city", "").strip()
            services = request.data.get("services", [])
            if not full_name or not email or not gender:
                return Response(
                    {
                        "requires_profile": True,
                        "message": "New user detected. Send full_name, email, gender and role with OTP verify.",
                    },
                    status=200,
                )
            if gender not in {User.Genders.MALE, User.Genders.FEMALE, User.Genders.OTHER}:
                return Response({"detail": "Invalid gender"}, status=400)
            if role not in {User.Roles.CUSTOMER, User.Roles.PROVIDER}:
                return Response({"detail": "Invalid role"}, status=400)
            if role == User.Roles.PROVIDER:
                if not isinstance(services, list) or not services:
                    return Response(
                        {"detail": "Provider signup requires at least one service"},
                        status=400,
                    )
                city = city or "Hyderabad"
            user = User.objects.create_user(
                phone=phone,
                full_name=full_name,
                email=email,
                gender=gender,
                role=role,
                city=city,
            )
            if role == User.Roles.PROVIDER:
                for service in Service.objects.filter(id__in=services):
                    ProviderServicePrice.objects.get_or_create(
                        provider=user,
                        service=service,
                        defaults={"price": service.base_price},
                    )
            tokens = token_pair_for_user(user)
            tokens["requires_profile"] = False
            tokens["is_new_user"] = True
            return Response(tokens)
        if not user.full_name and request.data.get("full_name"):
            user.full_name = request.data.get("full_name", "").strip()
        if not user.email and request.data.get("email"):
            user.email = request.data.get("email", "").strip()
        incoming_gender = request.data.get("gender", "").strip().upper()
        if not user.gender and incoming_gender in {
            User.Genders.MALE,
            User.Genders.FEMALE,
            User.Genders.OTHER,
        }:
            user.gender = incoming_gender
        user.save(update_fields=["full_name", "email", "gender"])
        tokens = token_pair_for_user(user)
        tokens["requires_profile"] = False
        tokens["is_new_user"] = False
        return Response(tokens)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me_view(request):
    return Response(UserProfileSerializer(request.user).data)


class MeUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        request.user.full_name = request.data.get("full_name", request.user.full_name)
        request.user.email = request.data.get("email", request.user.email)
        request.user.save(update_fields=["full_name", "email"])
        return Response({"message": "Profile updated"})


class MeChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        return Response({"detail": "Password auth is disabled. Use phone OTP login."}, status=400)


class CustomerCityView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        request.user.city = request.data.get("city", "").strip()
        request.user.save(update_fields=["city"])
        return Response({"message": "City saved"})


class ReverseGeoView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        lat = request.query_params.get("lat", "")
        lon = request.query_params.get("lon", "")
        return Response(
            {
                "city": "Demo City",
                "display_name": f"Approximate location for {lat},{lon}",
            }
        )


class NotificationsListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rows = Notification.objects.filter(user=request.user)
        return Response(NotificationSerializer(rows, many=True).data)


class NotificationReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, notification_id: int):
        Notification.objects.filter(id=notification_id, user=request.user).update(is_read=True)
        return Response({"message": "Notification marked read"})


class NotificationsReadAllView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(user=request.user).update(is_read=True)
        return Response({"message": "All notifications marked read"})


class DeviceTokenRegisterView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get("token", "").strip()
        platform = request.data.get("platform", "unknown").strip().lower()
        if not token:
            return Response({"detail": "token is required"}, status=400)
        token_row, _ = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                "user": request.user,
                "platform": platform or DeviceToken.Platforms.UNKNOWN,
                "is_active": True,
            },
        )
        return Response({"id": token_row.id, "message": "Device token saved"})


class DeviceTokenUnregisterView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get("token", "").strip()
        if not token:
            return Response({"detail": "token is required"}, status=400)
        DeviceToken.objects.filter(user=request.user, token=token).update(is_active=False)
        return Response({"message": "Device token removed"})


class SupportTicketsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role in {User.Roles.ADMIN, User.Roles.SUPPORT}:
            rows = SupportTicket.objects.select_related("booking", "booking__service", "requester").all()
        else:
            rows = SupportTicket.objects.filter(requester=request.user).select_related("booking", "booking__service")
        return Response(SupportTicketSerializer(rows, many=True).data)

    def post(self, request):
        issue_type = request.data.get("issue_type", "").strip()
        message = request.data.get("message", "").strip()
        booking_id = request.data.get("booking_id")
        if not issue_type:
            return Response({"detail": "issue_type is required"}, status=400)
        if not message:
            return Response({"detail": "message is required"}, status=400)

        booking = None
        if booking_id not in (None, ""):
            try:
                parsed_id = int(booking_id)
            except (TypeError, ValueError):
                return Response({"detail": "booking_id must be an integer"}, status=400)
            booking_query = Booking.objects.filter(id=parsed_id)
            if request.user.role == User.Roles.CUSTOMER:
                booking_query = booking_query.filter(customer=request.user)
            elif request.user.role == User.Roles.PROVIDER:
                booking_query = booking_query.filter(provider=request.user)
            booking = booking_query.first()
            if booking is None:
                return Response({"detail": "Booking not found for this account"}, status=404)

        ticket = SupportTicket.objects.create(
            requester=request.user,
            booking=booking,
            issue_type=issue_type,
            message=message,
        )

        support_users = User.objects.filter(
            Q(role=User.Roles.ADMIN) | Q(role=User.Roles.SUPPORT),
            is_active=True,
        )
        booking_ref = f' for booking #{booking.id}' if booking is not None else ''
        ticket_message = f'New support ticket #{ticket.id}{booking_ref}: {issue_type}.'
        for support_user in support_users:
            create_notification(
                user=support_user,
                title="New support ticket",
                message=ticket_message,
            )
        return Response(SupportTicketSerializer(ticket).data, status=201)


class SupportTicketStatusView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def post(self, request, ticket_id: int):
        status = request.data.get("status", "").strip().upper()
        if status not in {
            SupportTicket.Statuses.OPEN,
            SupportTicket.Statuses.IN_PROGRESS,
            SupportTicket.Statuses.RESOLVED,
            SupportTicket.Statuses.CLOSED,
        }:
            return Response({"detail": "Invalid ticket status"}, status=400)

        ticket = SupportTicket.objects.filter(id=ticket_id).first()
        if ticket is None:
            return Response({"detail": "Ticket not found"}, status=404)

        ticket.status = status
        ticket.save(update_fields=["status", "updated_at"])

        create_notification(
            user=ticket.requester,
            title="Support ticket updated",
            message=f"Your support ticket #{ticket.id} is now {status.replace('_', ' ').lower()}.",
        )
        return Response(SupportTicketSerializer(ticket).data)


class ProvidersListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        providers = (
            User.objects.filter(role=User.Roles.PROVIDER, is_active=True)
            .annotate(average_rating=Avg("received_reviews__rating"))
            .order_by("full_name", "phone")
        )
        data = [
            {
                "id": provider.id,
                "username": provider.username_label,
                "average_rating": provider.average_rating or 0,
            }
            for provider in providers
        ]
        return Response(data)


class ProviderMyServicesView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def get(self, request):
        services = Service.objects.filter(provider_prices__provider=request.user).distinct().order_by("name")
        return Response({"services": [{"id": s.id, "name": s.name} for s in services]})

    def post(self, request):
        service_ids = request.data.get("services", [])
        ProviderServicePrice.objects.filter(provider=request.user).exclude(service_id__in=service_ids).delete()
        for service in Service.objects.filter(id__in=service_ids):
            ProviderServicePrice.objects.get_or_create(
                provider=request.user,
                service=service,
                defaults={"price": service.base_price},
            )
        return Response({"message": "Services updated"})


class ProviderMyServicePricesView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def get(self, request):
        prices = ProviderServicePrice.objects.filter(provider=request.user).select_related("service").order_by("service__name")
        return Response({"prices": ProviderServicePriceSerializer(prices, many=True).data})

    def post(self, request):
        for row in request.data.get("prices", []):
            ProviderServicePrice.objects.filter(
                provider=request.user,
                service_id=row.get("service_id"),
            ).update(price=row.get("price", 0))
        return Response({"message": "Prices updated"})


class AdminUsersListView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        users = User.objects.all().order_by("full_name", "phone")
        return Response(AdminUserSerializer(users, many=True).data)

    def post(self, request):
        role = request.data.get("role", User.Roles.CUSTOMER).strip().upper()
        full_name = request.data.get("full_name", "").strip()
        email = request.data.get("email", "").strip()
        phone = request.data.get("phone", "").strip()
        gender = request.data.get("gender", User.Genders.OTHER).strip().upper()
        city = request.data.get("city", "").strip()
        services = request.data.get("services", [])

        if role not in {User.Roles.CUSTOMER, User.Roles.PROVIDER, User.Roles.SUPPORT}:
            return Response({"detail": "Invalid role"}, status=400)
        if not full_name:
            return Response({"detail": "full_name is required"}, status=400)
        if not email:
            return Response({"detail": "email is required"}, status=400)
        if not phone:
            return Response({"detail": "phone is required"}, status=400)
        if gender not in {User.Genders.MALE, User.Genders.FEMALE, User.Genders.OTHER}:
            return Response({"detail": "Invalid gender"}, status=400)
        if User.objects.filter(phone=phone).exists():
            return Response({"detail": "User with this phone already exists"}, status=400)

        if role == User.Roles.PROVIDER:
            if not city:
                return Response({"detail": "city is required for provider"}, status=400)
            if not isinstance(services, list) or not services:
                return Response(
                    {"detail": "At least one service is required for provider"},
                    status=400,
                )

        user = User.objects.create_user(
            phone=phone,
            full_name=full_name,
            email=email,
            gender=gender,
            city=city,
            role=role,
            is_active=True,
        )

        if role == User.Roles.PROVIDER:
            for service in Service.objects.filter(id__in=services):
                ProviderServicePrice.objects.get_or_create(
                    provider=user,
                    service=service,
                    defaults={"price": service.base_price},
                )

        return Response(AdminUserSerializer(user).data, status=201)


class ToggleAdminUserView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def post(self, request, user_id: int):
        user = User.objects.get(id=user_id)
        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])
        return Response({"message": "User status updated"})


class UserDeleteView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def delete(self, request, user_id: int):
        User.objects.filter(id=user_id).exclude(id=request.user.id).delete()
        return Response(status=204)


class AdminProviderServicesView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def post(self, request, user_id: int):
        provider = User.objects.get(id=user_id, role=User.Roles.PROVIDER)
        service_ids = request.data.get("services", [])
        ProviderServicePrice.objects.filter(provider=provider).exclude(service_id__in=service_ids).delete()
        for service in Service.objects.filter(id__in=service_ids):
            ProviderServicePrice.objects.get_or_create(
                provider=provider,
                service=service,
                defaults={"price": service.base_price},
            )
        return Response({"message": "Provider services updated"})


class AdminProviderServicePricesView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request, user_id: int):
        provider = User.objects.get(id=user_id, role=User.Roles.PROVIDER)
        prices = ProviderServicePrice.objects.filter(provider=provider).select_related("service").order_by("service__name")
        return Response({"prices": ProviderServicePriceSerializer(prices, many=True).data})

    def post(self, request, user_id: int):
        provider = User.objects.get(id=user_id, role=User.Roles.PROVIDER)
        for row in request.data.get("prices", []):
            ProviderServicePrice.objects.filter(
                provider=provider,
                service_id=row.get("service_id"),
            ).update(price=row.get("price", 0))
        return Response({"message": "Provider prices updated"})
