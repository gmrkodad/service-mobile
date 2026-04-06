from rest_framework import serializers

from .models import Category, ProviderServicePrice, Service


class ServiceSerializer(serializers.ModelSerializer):
    category = serializers.IntegerField(source="category_id")
    base_price = serializers.FloatField()
    starts_from = serializers.FloatField(allow_null=True)

    class Meta:
        model = Service
        fields = [
            "id",
            "category",
            "name",
            "description",
            "image_url",
            "base_price",
            "starts_from",
            "is_active",
        ]


class CategorySerializer(serializers.ModelSerializer):
    services = ServiceSerializer(many=True, read_only=True)

    class Meta:
        model = Category
        fields = ["id", "name", "description", "image_url", "is_active", "services"]


class AdminCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ["id", "name", "description", "image_url", "is_active"]


class AdminServiceSerializer(serializers.ModelSerializer):
    category = serializers.IntegerField(source="category_id")
    category_name = serializers.CharField(source="category.name", read_only=True)
    base_price = serializers.FloatField()

    class Meta:
        model = Service
        fields = [
            "id",
            "name",
            "description",
            "image_url",
            "base_price",
            "is_active",
            "category",
            "category_name",
        ]


class ProviderItemSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    full_name = serializers.CharField()
    rating = serializers.FloatField()
    price = serializers.FloatField(allow_null=True)
    city = serializers.CharField()
    phone = serializers.CharField()


class ProviderServicePriceInlineSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderServicePrice
        fields = ["service_id", "price"]

