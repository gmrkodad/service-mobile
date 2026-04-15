import uuid

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.contrib.auth import get_user_model
from django.db.models import Avg
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdminRole

from .models import Category, ProviderServicePrice, Service
from .serializers import (
    AdminCategorySerializer,
    AdminServiceSerializer,
    CategorySerializer,
)

User = get_user_model()


class CategoriesPublicView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        rows = Category.objects.filter(is_active=True).prefetch_related("services")
        return Response(CategorySerializer(rows, many=True).data)


class CategoriesPrivateView(CategoriesPublicView):
    permission_classes = [IsAuthenticated]


class ProvidersByServiceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, service_id: int):
        city = request.query_params.get("city", "").strip()
        prices = ProviderServicePrice.objects.filter(
            service_id=service_id,
            provider__role=User.Roles.PROVIDER,
            provider__is_active=True,
        ).select_related("provider")
        if city:
            prices = prices.filter(provider__city__iexact=city)
        provider_ids = [row.provider_id for row in prices]
        ratings = {
            row["provider_id"]: row["avg_rating"] or 0
            for row in ProviderServicePrice.objects.filter(provider_id__in=provider_ids)
            .values("provider_id")
            .annotate(avg_rating=Avg("provider__received_reviews__rating"))
        }
        data = [
            {
                "id": row.provider.id,
                "user_id": row.provider.id,
                "username": row.provider.username,
                "full_name": row.provider.full_name,
                "rating": ratings.get(row.provider.id, 0),
                "price": float(row.price),
                "city": row.provider.city,
                "phone": row.provider.phone,
            }
            for row in prices
        ]
        return Response(data)


class AdminCategoriesView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        return Response(AdminCategorySerializer(Category.objects.all(), many=True).data)

    def post(self, request):
        serializer = AdminCategorySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        category = serializer.save()
        return Response(AdminCategorySerializer(category).data, status=201)


class AdminCategoryDetailView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def put(self, request, category_id: int):
        category = Category.objects.get(id=category_id)
        serializer = AdminCategorySerializer(category, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def delete(self, request, category_id: int):
        Category.objects.filter(id=category_id).delete()
        return Response(status=204)


class AdminServicesView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get(self, request):
        services = Service.objects.select_related("category").all()
        return Response(AdminServiceSerializer(services, many=True).data)

    def post(self, request):
        serializer = AdminServiceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        service = serializer.save()
        return Response(AdminServiceSerializer(service).data, status=201)


class AdminServiceDetailView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]

    def put(self, request, service_id: int):
        service = Service.objects.get(id=service_id)
        serializer = AdminServiceSerializer(service, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def delete(self, request, service_id: int):
        Service.objects.filter(id=service_id).delete()
        return Response(status=204)


class AdminUploadIconView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        uploaded = request.FILES.get("file")
        if uploaded is None:
            return Response(
                {"detail": "No file uploaded. Use form field 'file'."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not uploaded.content_type or not uploaded.content_type.startswith("image/"):
            return Response(
                {"detail": "Only image files are allowed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        extension = uploaded.name.rsplit(".", 1)[-1].lower() if "." in uploaded.name else "png"
        filename = f"service_icons/{uuid.uuid4().hex}.{extension}"
        saved_path = default_storage.save(filename, ContentFile(uploaded.read()))
        image_url = request.build_absolute_uri(default_storage.url(saved_path))
        return Response({"image_url": image_url}, status=status.HTTP_201_CREATED)
