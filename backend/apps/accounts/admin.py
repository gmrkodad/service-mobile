from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import Notification, OtpCode, User


@admin.register(User)
class AppUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (
        ("Service App", {"fields": ("role", "full_name", "phone", "city")}),
    )
    list_display = ("username", "email", "role", "is_active", "is_staff")


admin.site.register(OtpCode)
admin.site.register(Notification)

