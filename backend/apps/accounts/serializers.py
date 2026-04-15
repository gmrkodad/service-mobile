from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from apps.services.models import ProviderServicePrice, Service

from .models import Notification, SupportTicket, User


class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["username", "role", "email", "phone", "full_name", "gender", "city"]

    def get_username(self, obj):
        return obj.username_label


class SignupCustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["full_name", "email", "phone", "gender"]

    def create(self, validated_data):
        return User.objects.create_user(**validated_data, role=User.Roles.CUSTOMER)


class SignupProviderSerializer(SignupCustomerSerializer):
    city = serializers.CharField()
    services = serializers.ListField(child=serializers.IntegerField(), allow_empty=True)

    class Meta(SignupCustomerSerializer.Meta):
        fields = SignupCustomerSerializer.Meta.fields + ["city", "services"]

    def create(self, validated_data):
        service_ids = validated_data.pop("services", [])
        user = User.objects.create_user(**validated_data, role=User.Roles.PROVIDER)
        for service in Service.objects.filter(id__in=service_ids):
            ProviderServicePrice.objects.get_or_create(
                provider=user,
                service=service,
                defaults={"price": service.base_price},
            )
        return user


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "message", "is_read", "created_at"]


class SupportTicketSerializer(serializers.ModelSerializer):
    booking_id = serializers.IntegerField(source="booking.id", allow_null=True)
    booking_label = serializers.SerializerMethodField()
    requester_username = serializers.CharField(source="requester.username", read_only=True)
    requester_role = serializers.CharField(source="requester.role", read_only=True)

    class Meta:
        model = SupportTicket
        fields = [
            "id",
            "issue_type",
            "message",
            "status",
            "booking_id",
            "booking_label",
            "requester_username",
            "requester_role",
            "created_at",
        ]

    def get_booking_label(self, obj):
        if obj.booking_id is None or obj.booking is None:
            return ""
        service_name = obj.booking.service.name if obj.booking.service_id else "Service"
        return f"#{obj.booking_id} {service_name}"


class BasicServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Service
        fields = ["id", "name"]


class ProviderServicePriceSerializer(serializers.ModelSerializer):
    service_id = serializers.IntegerField(source="service.id")
    service_name = serializers.CharField(source="service.name")
    base_price = serializers.FloatField(source="service.base_price")

    class Meta:
        model = ProviderServicePrice
        fields = ["service_id", "service_name", "price", "base_price"]


class AdminUserSerializer(serializers.ModelSerializer):
    username = serializers.SerializerMethodField()
    provider_services = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "full_name",
            "email",
            "role",
            "is_active",
            "city",
            "phone",
            "provider_services",
        ]

    def get_provider_services(self, obj):
        services = Service.objects.filter(provider_prices__provider=obj).distinct().order_by("name")
        return BasicServiceSerializer(services, many=True).data

    def get_username(self, obj):
        return obj.username_label


def token_pair_for_user(user: User) -> dict:
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}
