from django.contrib import admin

from .models import DeviceToken, Notification, OtpCode, SupportTicket, User


@admin.register(User)
class AppUserAdmin(admin.ModelAdmin):
    list_display = ("id", "phone", "full_name", "email", "gender", "role", "is_active", "is_staff")
    search_fields = ("phone", "full_name", "email")
    list_filter = ("role", "gender", "is_active", "is_staff")


admin.site.register(OtpCode)
admin.site.register(Notification)
admin.site.register(DeviceToken)
admin.site.register(SupportTicket)
