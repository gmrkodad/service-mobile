from django.urls import path

from .views import (
    admin_bookings_view,
    admin_categories_view,
    admin_dashboard_view,
    admin_reviews_view,
    admin_services_view,
    admin_tickets_view,
    admin_users_view,
    console_home_view,
    console_login_view,
    console_logout_view,
    support_dashboard_view,
    support_tickets_view,
    ticket_status_update_view,
)

urlpatterns = [
    path("", console_home_view, name="console_home"),
    path("login/", console_login_view, name="console_login"),
    path("logout/", console_logout_view, name="console_logout"),
    path("admin/", admin_dashboard_view, name="console_admin_dashboard"),
    path("admin/users/", admin_users_view, name="console_admin_users"),
    path("admin/bookings/", admin_bookings_view, name="console_admin_bookings"),
    path("admin/categories/", admin_categories_view, name="console_admin_categories"),
    path("admin/services/", admin_services_view, name="console_admin_services"),
    path("admin/tickets/", admin_tickets_view, name="console_admin_tickets"),
    path("admin/reviews/", admin_reviews_view, name="console_admin_reviews"),
    path("support/", support_dashboard_view, name="console_support_dashboard"),
    path("support/tickets/", support_tickets_view, name="console_support_tickets"),
    path("tickets/<int:ticket_id>/status/", ticket_status_update_view, name="console_ticket_status"),
]
