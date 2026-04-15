from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, phone, password=None, **extra_fields):
        if not phone:
            raise ValueError("The phone number must be set")
        user = self.model(phone=str(phone).strip(), **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        extra_fields.setdefault("role", User.Roles.ADMIN)
        return self.create_user(phone, password=password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    class Roles(models.TextChoices):
        ADMIN = "ADMIN", "Admin"
        SUPPORT = "SUPPORT", "Support"
        CUSTOMER = "CUSTOMER", "Customer"
        PROVIDER = "PROVIDER", "Provider"

    class Genders(models.TextChoices):
        MALE = "MALE", "Male"
        FEMALE = "FEMALE", "Female"
        OTHER = "OTHER", "Other"

    username = None
    email = models.EmailField(blank=True)
    full_name = models.CharField(max_length=255, blank=True)
    gender = models.CharField(max_length=16, choices=Genders.choices, blank=True)
    phone = models.CharField(max_length=32, unique=True)
    city = models.CharField(max_length=128, blank=True)
    role = models.CharField(
        max_length=16,
        choices=Roles.choices,
        default=Roles.CUSTOMER,
    )
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = []

    objects = UserManager()

    @property
    def display_name(self) -> str:
        return (self.full_name or "").strip() or self.phone

    @property
    def username(self) -> str:
        return self.display_name

    @property
    def username_label(self) -> str:
        return self.display_name


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


class DeviceToken(models.Model):
    class Platforms(models.TextChoices):
        ANDROID = "android", "Android"
        IOS = "ios", "iOS"
        WEB = "web", "Web"
        MACOS = "macos", "macOS"
        WINDOWS = "windows", "Windows"
        LINUX = "linux", "Linux"
        UNKNOWN = "unknown", "Unknown"

    user = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="device_tokens",
    )
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(
        max_length=16,
        choices=Platforms.choices,
        default=Platforms.UNKNOWN,
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]


class SupportTicket(models.Model):
    class Statuses(models.TextChoices):
        OPEN = "OPEN", "Open"
        IN_PROGRESS = "IN_PROGRESS", "In progress"
        RESOLVED = "RESOLVED", "Resolved"
        CLOSED = "CLOSED", "Closed"

    requester = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="support_tickets",
    )
    booking = models.ForeignKey(
        "bookings.Booking",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="support_tickets",
    )
    issue_type = models.CharField(max_length=64)
    message = models.TextField()
    status = models.CharField(
        max_length=16,
        choices=Statuses.choices,
        default=Statuses.OPEN,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
