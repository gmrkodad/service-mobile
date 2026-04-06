from rest_framework import serializers

from .models import Booking, Review


class BookingSerializer(serializers.ModelSerializer):
    service_name = serializers.SerializerMethodField()
    service_names = serializers.SerializerMethodField()
    category = serializers.SerializerMethodField()
    provider_username = serializers.SerializerMethodField()
    provider_full_name = serializers.SerializerMethodField()
    customer_username = serializers.SerializerMethodField()
    has_review = serializers.SerializerMethodField()
    review_rating = serializers.SerializerMethodField()
    review_comment = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            "id",
            "service_name",
            "service_names",
            "category",
            "provider_username",
            "provider_full_name",
            "customer_username",
            "address",
            "scheduled_date",
            "time_slot",
            "status",
            "has_review",
            "review_rating",
            "review_comment",
        ]

    def get_service_name(self, obj):
        if obj.service:
            return obj.service.name
        first = obj.services.order_by("name").first()
        return first.name if first else ""

    def get_service_names(self, obj):
        return list(obj.services.order_by("name").values_list("name", flat=True))

    def get_category(self, obj):
        service = obj.service or obj.services.select_related("category").first()
        return service.category.name if service and service.category else ""

    def get_provider_username(self, obj):
        return obj.provider.username if obj.provider else ""

    def get_provider_full_name(self, obj):
        return obj.provider.full_name if obj.provider else ""

    def get_customer_username(self, obj):
        return obj.customer.username if obj.customer else ""

    def get_has_review(self, obj):
        return hasattr(obj, "review")

    def get_review_rating(self, obj):
        return obj.review.rating if hasattr(obj, "review") else None

    def get_review_comment(self, obj):
        return obj.review.comment if hasattr(obj, "review") else ""


class AdminReviewSerializer(serializers.ModelSerializer):
    booking_id = serializers.IntegerField(source="booking.id")
    service_name = serializers.SerializerMethodField()
    provider_username = serializers.CharField(source="provider.username")
    author_username = serializers.CharField(source="author.username")

    class Meta:
        model = Review
        fields = [
            "id",
            "booking_id",
            "service_name",
            "provider_username",
            "author_username",
            "rating",
            "comment",
            "created_at",
        ]

    def get_service_name(self, obj):
        if obj.booking.service:
            return obj.booking.service.name
        first = obj.booking.services.order_by("name").first()
        return first.name if first else ""

