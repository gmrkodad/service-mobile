from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Notification
from apps.accounts.permissions import IsAdminRole, IsProviderRole
from apps.services.models import ProviderServicePrice, Service

from .models import Booking, Review
from .serializers import AdminReviewSerializer, BookingSerializer

User = get_user_model()


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
        provider = User.objects.get(id=request.data["provider"])
        service = Service.objects.get(id=request.data["service"])
        booking = Booking.objects.create(
            customer=request.user,
            provider=provider,
            service=service,
            address=request.data.get("address", ""),
            scheduled_date=request.data.get("scheduled_date"),
            time_slot=request.data.get("time_slot", ""),
            status=Booking.Statuses.ASSIGNED,
        )
        booking.services.set(Service.objects.filter(id__in=request.data.get("service_ids", [])))
        Notification.objects.create(
            user=provider,
            message=f"New booking #{booking.id} assigned to you.",
        )
        return Response({"booking_id": booking.id}, status=201)


class CustomerBookingsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rows = Booking.objects.filter(customer=request.user).select_related("service", "provider", "customer")
        return Response(BookingSerializer(rows, many=True).data)


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
        Notification.objects.create(
            user=booking.provider,
            message=f"New review received for booking #{booking.id}.",
        )
        return Response({"id": review.id}, status=201)


class ProviderDashboardView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def get(self, request):
        rows = Booking.objects.filter(provider=request.user).select_related("service", "provider", "customer")
        return Response(BookingSerializer(rows, many=True).data)


class ProviderActionView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def post(self, request, booking_id: int):
        booking = Booking.objects.get(id=booking_id, provider=request.user)
        action = request.data.get("action", "").lower()
        if action == "accept":
            booking.status = Booking.Statuses.ACCEPTED
        elif action == "reject":
            booking.status = Booking.Statuses.CANCELLED
        booking.save(update_fields=["status"])
        return Response({"message": "Booking updated"})


class ProviderStatusView(APIView):
    permission_classes = [IsAuthenticated, IsProviderRole]

    def post(self, request, booking_id: int):
        booking = Booking.objects.get(id=booking_id, provider=request.user)
        booking.status = request.data.get("status", booking.status)
        booking.save(update_fields=["status"])
        return Response({"message": "Status updated"})


class AdminAllBookingsView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        rows = Booking.objects.all().select_related("service", "provider", "customer")
        return Response(BookingSerializer(rows, many=True).data)


class AssignProviderView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def post(self, request, booking_id: int):
        booking = Booking.objects.get(id=booking_id)
        provider = User.objects.get(id=request.data.get("provider_id"), role=User.Roles.PROVIDER)
        booking.provider = provider
        booking.status = Booking.Statuses.ASSIGNED
        booking.save(update_fields=["provider", "status"])
        Notification.objects.create(
            user=provider,
            message=f"Booking #{booking.id} was assigned by admin.",
        )
        return Response({"message": "Provider assigned"})


class AdminReviewsView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        rows = Review.objects.select_related("booking", "provider", "author").all()
        return Response(AdminReviewSerializer(rows, many=True).data)
