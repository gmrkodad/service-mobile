import random

from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.push import create_notification
from apps.accounts.permissions import IsAdminRole, IsProviderRole
from apps.services.models import ProviderServicePrice, Service

from .models import Booking, Review
from .serializers import AdminReviewSerializer, BookingSerializer

User = get_user_model()


def _otp4() -> str:
    return f"{random.randint(0, 9999):04d}"


def _normalize_city(value: str) -> str:
    raw = (value or "").strip()
    if not raw:
        return ""
    raw = raw.split(",", 1)[0].strip()
    return " ".join(raw.split()).lower()


def _provider_busy_for_slot(provider, scheduled_date, time_slot) -> bool:
    return Booking.objects.filter(
        provider=provider,
        scheduled_date=scheduled_date,
        time_slot=time_slot,
        status__in=[
            Booking.Statuses.ASSIGNED,
            Booking.Statuses.ACCEPTED,
            Booking.Statuses.IN_PROGRESS,
        ],
    ).exists()


class ProviderServicesForBookingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, provider_id: int):
        services = Service.objects.filter(provider_prices__provider_id=provider_id).distinct().order_by("name")
        data = [
            {
                "id": service.id,
                "category": service.category_id,
                "name": service.name,
                "description": service.description,
                "image_url": service.image_url,
                "base_price": float(service.base_price),
                "starts_from": float(service.starts_from) if service.starts_from is not None else None,
                "is_active": service.is_active,
            }
            for service in services
        ]
        return Response(data)


class BookingCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        service_id = request.data.get("service")
        raw_service_ids = request.data.get("service_ids", [])
        provider_id = request.data.get("provider")
        scheduled_date = request.data.get("scheduled_date")
        time_slot = request.data.get("time_slot", "")

        if not isinstance(raw_service_ids, list):
            return Response({"detail": "service_ids must be a list"}, status=400)
        try:
            service_ids = [int(value) for value in raw_service_ids]
        except (TypeError, ValueError):
            return Response({"detail": "service_ids must contain valid ids"}, status=400)

        service = Service.objects.filter(id=service_id, is_active=True).first()
        if service is None:
            return Response({"detail": "Invalid service"}, status=400)

        selected_services = Service.objects.filter(id__in=service_ids, is_active=True)
        selected_count = selected_services.count()
        if selected_count != len(set(service_ids)):
            return Response({"detail": "One or more selected services are invalid"}, status=400)

        required_service_ids = set(service_ids)
        if service.id not in required_service_ids:
            required_service_ids.add(service.id)
        if not provider_id:
            return Response({"detail": "Please select a provider"}, status=400)
        try:
            provider_id = int(provider_id)
        except (TypeError, ValueError):
            return Response({"detail": "Invalid provider id"}, status=400)
        provider = User.objects.filter(
            id=provider_id,
            role=User.Roles.PROVIDER,
            is_active=True,
        ).first()
        if provider is None:
            return Response({"detail": "Selected provider is not valid"}, status=400)

        customer_city = _normalize_city(getattr(request.user, "city", ""))
        provider_city = _normalize_city(getattr(provider, "city", ""))
        if customer_city and provider_city and provider_city != customer_city:
            return Response({"detail": "Selected provider is not available in your city"}, status=400)

        provider_service_ids = set(
            ProviderServicePrice.objects.filter(provider=provider).values_list("service_id", flat=True)
        )
        if not required_service_ids.issubset(provider_service_ids):
            return Response(
                {"detail": "Selected provider does not offer all selected services"},
                status=400,
            )

        if _provider_busy_for_slot(provider, scheduled_date, time_slot):
            return Response(
                {"detail": "Selected provider is not available for this slot"},
                status=400,
            )

        booking = Booking.objects.create(
            customer=request.user,
            provider=provider,
            service=service,
            address=request.data.get("address", ""),
            scheduled_date=scheduled_date,
            time_slot=time_slot,
            start_otp=_otp4(),
            end_otp=_otp4(),
            status=Booking.Statuses.ASSIGNED,
        )
        booking.services.set(selected_services)
        create_notification(
            user=provider,
            title="New booking assigned",
            message=f"Booking #{booking.id} has been assigned to you.",
        )
        return Response({"booking_id": booking.id}, status=201)


class CustomerBookingsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rows = Booking.objects.filter(customer=request.user).select_related("service", "provider", "customer")
        return Response(BookingSerializer(rows, many=True, context={"request": request}).data)


class ReviewCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, booking_id: int):
        booking = Booking.objects.get(id=booking_id, customer=request.user)
        review, _ = Review.objects.update_or_create(
            booking=booking,
            defaults={
                "provider": booking.provider,
                "author": request.user,
                "rating": request.data.get("rating", 5),
                "comment": request.data.get("comment", ""),
            },
        )
        create_notification(
            user=booking.provider,
            title="New review received",
            message=f"New review received for booking #{booking.id}.",
        )
        return Response({"id": review.id}, status=201)


class ProviderDashboardView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def get(self, request):
        rows = Booking.objects.filter(provider=request.user).select_related(
            "service",
            "provider",
            "customer",
        )
        return Response(BookingSerializer(rows, many=True, context={"request": request}).data)


class ProviderActionView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def post(self, request, booking_id: int):
        action = request.data.get("action", "").lower()
        if action == "accept":
            booking = Booking.objects.filter(id=booking_id, provider=request.user).first()
            if booking is None:
                return Response({"detail": "Booking not found"}, status=404)
            if booking.status not in {Booking.Statuses.ASSIGNED, Booking.Statuses.PENDING}:
                return Response({"detail": "Booking cannot be accepted now"}, status=400)
            booking.status = Booking.Statuses.ACCEPTED
            booking.save(update_fields=["status"])
            create_notification(
                user=booking.customer,
                title="Provider confirmed booking",
                message=f"Provider confirmed booking #{booking.id}.",
            )
            return Response({"message": "Booking accepted"})

        if action == "reject":
            booking = Booking.objects.filter(id=booking_id, provider=request.user).first()
            if booking and booking.status in {Booking.Statuses.ACCEPTED, Booking.Statuses.ASSIGNED}:
                booking.status = Booking.Statuses.CANCELLED
                booking.save(update_fields=["status"])
                return Response({"message": "Booking rejected"})
            return Response({"message": "Skipped"})

        return Response({"detail": "Invalid action"}, status=400)


class ProviderStatusView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def post(self, request, booking_id: int):
        booking = Booking.objects.filter(id=booking_id, provider=request.user).first()
        if booking is None:
            return Response({"detail": "Booking not found"}, status=404)

        status = request.data.get("status", booking.status)
        otp = str(request.data.get("otp", "")).strip()

        if status == Booking.Statuses.IN_PROGRESS:
            if booking.status not in {Booking.Statuses.ACCEPTED, Booking.Statuses.ASSIGNED}:
                return Response({"detail": "Booking cannot be started now"}, status=400)
            if otp != booking.start_otp:
                return Response({"detail": "Invalid start OTP"}, status=400)
            booking.status = Booking.Statuses.IN_PROGRESS
            booking.save(update_fields=["status"])
            create_notification(
                user=booking.customer,
                title="Service started",
                message=f"Booking #{booking.id} has started.",
            )
            return Response({"message": "Status updated"})

        if status == Booking.Statuses.COMPLETED:
            if booking.status != Booking.Statuses.IN_PROGRESS:
                return Response({"detail": "Booking is not in progress"}, status=400)
            if otp != booking.end_otp:
                return Response({"detail": "Invalid completion OTP"}, status=400)
            booking.status = Booking.Statuses.COMPLETED
            booking.save(update_fields=["status"])
            create_notification(
                user=booking.customer,
                title="Service completed",
                message=f"Booking #{booking.id} has been marked completed.",
            )
            return Response({"message": "Status updated"})

        return Response({"detail": "Unsupported status transition"}, status=400)


class AdminAllBookingsView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        rows = Booking.objects.all().select_related("service", "provider", "customer")
        return Response(BookingSerializer(rows, many=True, context={"request": request}).data)


class AssignProviderView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def post(self, request, booking_id: int):
        booking = Booking.objects.get(id=booking_id)
        provider = User.objects.get(id=request.data.get("provider_id"), role=User.Roles.PROVIDER)
        booking.provider = provider
        booking.status = Booking.Statuses.ASSIGNED
        booking.save(update_fields=["provider", "status"])
        create_notification(
            user=provider,
            title="Booking assigned by admin",
            message=f"Booking #{booking.id} was assigned by admin.",
        )
        return Response({"message": "Provider assigned"})


class AdminReviewsView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        rows = Review.objects.select_related("booking", "provider", "author").all()
        return Response(AdminReviewSerializer(rows, many=True).data)
