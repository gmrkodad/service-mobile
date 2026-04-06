from django.urls import path

from .views import (
    AdminCategoriesView,
    AdminCategoryDetailView,
    AdminServicesView,
    AdminServiceDetailView,
    CategoriesPrivateView,
    CategoriesPublicView,
    ProvidersByServiceView,
)


urlpatterns = [
    path("categories/", CategoriesPrivateView.as_view()),
    path("categories/public/", CategoriesPublicView.as_view()),
    path("<int:service_id>/providers/", ProvidersByServiceView.as_view()),
    path("admin/categories/", AdminCategoriesView.as_view()),
    path("admin/categories/<int:category_id>/", AdminCategoryDetailView.as_view()),
    path("admin/services/", AdminServicesView.as_view()),
    path("admin/services/<int:service_id>/", AdminServiceDetailView.as_view()),
]

