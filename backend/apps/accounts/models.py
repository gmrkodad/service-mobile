from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    class Roles(models.TextChoices):
        ADMIN = "ADMIN", "Admin"
        CUSTOMER = "CUSTOMER", "Customer"
        PROVIDER = "PROVIDER", "Provider"

    email = models.EmailField(blank=True)
    full_name = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=32, blank=True)
    city = models.CharField(max_length=128, blank=True)
    role = models.CharField(
        max_length=16,
        choices=Roles.choices,
        default=Roles.CUSTOMER,
    )


class OtpCode(models.Model):
    class Purposes(models.TextChoices):
        LOGIN = "LOGIN", "Login"
        SIGNUP = "SIGNUP", "Signup"

    phone = models.CharField(max_length=32)
    purpose = models.CharField(max_length=16, choices=Purposes.choices)
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class Notification(models.Model):
    user = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

