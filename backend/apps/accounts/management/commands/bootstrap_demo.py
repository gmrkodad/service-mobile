from django.core.management.base import BaseCommand

from apps.accounts.models import Notification, User
from apps.services.models import Category, ProviderServicePrice, Service


class Command(BaseCommand):
    help = "Create demo data and a bootstrap admin user."

    def add_arguments(self, parser):
        parser.add_argument("--admin-username", default="admin")
        parser.add_argument("--admin-password", default="admin12345")
        parser.add_argument("--admin-email", default="admin@example.com")

    def handle(self, *args, **options):
        admin, created = User.objects.get_or_create(
            username=options["admin_username"],
            defaults={
                "email": options["admin_email"],
                "full_name": "Platform Admin",
                "role": User.Roles.ADMIN,
                "is_staff": True,
                "is_superuser": True,
            },
        )
        admin.email = options["admin_email"]
        admin.role = User.Roles.ADMIN
        admin.is_staff = True
        admin.is_superuser = True
        admin.set_password(options["admin_password"])
        admin.save()

        cleaning, _ = Category.objects.get_or_create(
            name="Home Cleaning",
            defaults={
                "description": "General home cleaning and deep cleaning",
                "image_url": "",
            },
        )
        repairs, _ = Category.objects.get_or_create(
            name="Repairs",
            defaults={
                "description": "Electrical, plumbing, and home repair services",
                "image_url": "",
            },
        )

        services = [
            (cleaning, "Deep Cleaning", 1499),
            (cleaning, "Kitchen Cleaning", 899),
            (repairs, "Plumbing Visit", 699),
            (repairs, "Electrician Visit", 799),
        ]
        created_services = []
        for category, name, base_price in services:
            service, _ = Service.objects.get_or_create(
                category=category,
                name=name,
                defaults={
                    "description": name,
                    "image_url": "",
                    "base_price": base_price,
                    "starts_from": base_price,
                },
            )
            created_services.append(service)

        provider, _ = User.objects.get_or_create(
            username="provider1",
            defaults={
                "full_name": "Demo Provider",
                "email": "provider@example.com",
                "phone": "9999999999",
                "city": "Demo City",
                "role": User.Roles.PROVIDER,
            },
        )
        provider.set_password("provider12345")
        provider.role = User.Roles.PROVIDER
        provider.save()

        customer, _ = User.objects.get_or_create(
            username="customer1",
            defaults={
                "full_name": "Demo Customer",
                "email": "customer@example.com",
                "phone": "8888888888",
                "city": "Demo City",
                "role": User.Roles.CUSTOMER,
            },
        )
        customer.set_password("customer12345")
        customer.role = User.Roles.CUSTOMER
        customer.save()

        for service in created_services:
            ProviderServicePrice.objects.get_or_create(
                provider=provider,
                service=service,
                defaults={"price": service.base_price},
            )

        Notification.objects.get_or_create(
            user=admin,
            message="Demo admin account is ready.",
        )

        self.stdout.write(
            self.style.SUCCESS(
                f"Bootstrap complete. Admin user: {admin.username} (created={created})"
            )
        )

