import random

from django.contrib.auth import get_user_model
from django.db.models import Avg
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.services.models import ProviderServicePrice, Service

from .models import Notification, OtpCode
from .permissions import IsAdminRole, IsProviderRole
from .serializers import (
    AdminUserSerializer,
    NotificationSerializer,
    ProviderServicePriceSerializer,
    SignupCustomerSerializer,
    SignupProviderSerializer,
    UserProfileSerializer,
    token_pair_for_user,
)

User = get_user_model()


def _issue_otp(phone: str, purpose: str) -> str:
    code = f"{random.randint(0, 999999):06d}"
    OtpCode.objects.create(phone=phone, purpose=purpose, code=code)
    return code


class OtpSendView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get("phone", "").strip()
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
        otp_row = OtpCode.objects.filter(
            phone=phone,
            purpose=OtpCode.Purposes.LOGIN,
            code=otp,
        ).first()
        if not otp_row:
            return Response({"detail": "Invalid OTP"}, status=400)
        user = User.objects.filter(phone=phone).first()
        if not user:
            return Response({"detail": "No user found for this phone"}, status=404)
        return Response(token_pair_for_user(user))


class SignupCustomerView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SignupCustomerSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({"message": "Customer account created"}, status=201)


class SignupProviderView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SignupProviderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({"message": "Provider account created"}, status=201)


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
        current_password = request.data.get("current_password", "")
        new_password = request.data.get("new_password", "")
        confirm_password = request.data.get("confirm_password", "")
        if not request.user.check_password(current_password):
            return Response({"detail": "Current password is incorrect"}, status=400)
        if new_password != confirm_password:
            return Response({"detail": "Passwords do not match"}, status=400)
        request.user.set_password(new_password)
        request.user.save()
        return Response({"message": "Password updated"})


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


class ProvidersListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        providers = (
            User.objects.filter(role=User.Roles.PROVIDER, is_active=True)
            .annotate(average_rating=Avg("received_reviews__rating"))
            .order_by("username")
        )
        data = [
            {
                "id": provider.id,
                "username": provider.username,
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
        users = User.objects.all().order_by("username")
        return Response(AdminUserSerializer(users, many=True).data)


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

