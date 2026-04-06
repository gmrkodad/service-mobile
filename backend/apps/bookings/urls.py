from django.urls import path

from .views import (
    AdminAllBookingsView,
    AdminReviewsView,
    AssignProviderView,
    BookingCreateView,
    CustomerBookingsView,
    ProviderActionView,
    ProviderDashboardView,
    ProviderServicesForBookingView,
    ProviderStatusView,
    ReviewCreateView,
)


urlpatterns = [
    path("provider-services/<int:provider_id>/", ProviderServicesForBookingView.as_view()),
    path("create/", BookingCreateView.as_view()),
    path("my/", CustomerBookingsView.as_view()),
    path("review/<int:booking_id>/", ReviewCreateView.as_view()),
    path("provider/dashboard/", ProviderDashboardView.as_view()),
    path("provider/action/<int:booking_id>/", ProviderActionView.as_view()),
    path("provider/update-status/<int:booking_id>/", ProviderStatusView.as_view()),
    path("admin/all/", AdminAllBookingsView.as_view()),
    path("assign/<int:booking_id>/", AssignProviderView.as_view()),
    path("admin/reviews/", AdminReviewsView.as_view()),
]

