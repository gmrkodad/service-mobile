from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from apps.services.models import ProviderServicePrice, Service

from .models import Notification, User


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["username", "role", "email", "phone", "full_name"]


class SignupCustomerSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["full_name", "username", "email", "password", "phone"]

    def validate_password(self, value):
        validate_password(value)
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data, role=User.Roles.CUSTOMER)
        user.set_password(password)
        user.save()
        return user


class SignupProviderSerializer(SignupCustomerSerializer):
    city = serializers.CharField()
    services = serializers.ListField(child=serializers.IntegerField(), allow_empty=True)

    class Meta(SignupCustomerSerializer.Meta):
        fields = SignupCustomerSerializer.Meta.fields + ["city", "services"]

    def create(self, validated_data):
        service_ids = validated_data.pop("services", [])
        password = validated_data.pop("password")
        user = User(**validated_data, role=User.Roles.PROVIDER)
        user.set_password(password)
        user.save()
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


def token_pair_for_user(user: User) -> dict:
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}

