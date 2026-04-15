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

        catalog = [
            {
                "category": "Cleaning & Pest Control",
                "description": "Home deep cleaning and pest control solutions",
                "services": [
                    ("Bathroom Cleaning", 499),
                    ("Kitchen Deep Cleaning", 799),
                    ("Sofa Cleaning", 899),
                    ("Carpet Cleaning", 649),
                    ("Full Home Deep Cleaning", 2499),
                    ("Cockroach Control", 1099),
                    ("Termite Control", 1899),
                    ("Mosquito Control", 999),
                    ("Bed Bug Treatment", 1699),
                ],
            },
            {
                "category": "Appliance Repair",
                "description": "Repair and maintenance for home appliances",
                "services": [
                    ("AC Service & Repair", 499),
                    ("Washing Machine Repair", 399),
                    ("Refrigerator Repair", 399),
                    ("Microwave Repair", 349),
                    ("RO/Water Purifier Repair", 299),
                    ("Geyser Repair", 349),
                    ("TV Repair", 399),
                    ("Chimney Repair", 449),
                ],
            },
            {
                "category": "Electrician, Plumber & Carpenter",
                "description": "On-demand home repairs and installation jobs",
                "services": [
                    ("Electrician Visit", 199),
                    ("Plumber Visit", 199),
                    ("Carpenter Visit", 249),
                    ("Drill & Hang", 149),
                    ("Switch & Socket Replacement", 149),
                    ("Tap & Mixer Installation", 199),
                    ("Leakage Repair", 249),
                    ("Door Lock Repair", 249),
                ],
            },
            {
                "category": "Salon & Spa at Home",
                "description": "Beauty and wellness services at your doorstep",
                "services": [
                    ("Women Haircut", 499),
                    ("Manicure", 599),
                    ("Pedicure", 699),
                    ("Facial", 899),
                    ("Waxing", 799),
                    ("Bridal Makeup", 4999),
                    ("Spa Therapy", 1299),
                ],
            },
            {
                "category": "Men's Grooming",
                "description": "Grooming and self-care services for men",
                "services": [
                    ("Men Haircut", 249),
                    ("Beard Styling", 199),
                    ("Facial for Men", 699),
                    ("Hair Color", 799),
                    ("Head Massage", 349),
                ],
            },
            {
                "category": "Painting & Waterproofing",
                "description": "Interior/exterior painting and leakage prevention",
                "services": [
                    ("Interior Painting", 14999),
                    ("Exterior Painting", 19999),
                    ("Waterproofing", 5999),
                    ("Wall Texture", 6999),
                    ("Wood Polish", 3499),
                ],
            },
            {
                "category": "Home Renovation",
                "description": "Design and renovation support for homes",
                "services": [
                    ("Modular Kitchen Consultation", 999),
                    ("Bathroom Renovation Consultation", 999),
                    ("False Ceiling Work", 4999),
                    ("Custom Furniture Consultation", 999),
                    ("Flooring Consultation", 999),
                ],
            },
            {
                "category": "Packs & Shifts",
                "description": "Relocation and packing assistance",
                "services": [
                    ("Local House Shifting", 4999),
                    ("Office Shifting", 8999),
                    ("Intercity Relocation", 14999),
                    ("Packing Only", 2999),
                ],
            },
            {
                "category": "Native Water Purifier",
                "description": "Water purifier installation and recurring maintenance",
                "services": [
                    ("RO Installation", 499),
                    ("RO Annual Maintenance", 2499),
                    ("Filter Replacement", 799),
                    ("RO Breakdown Repair", 349),
                ],
            },
            {
                "category": "Smart Home & Security",
                "description": "Installation and setup of smart devices and security gear",
                "services": [
                    ("CCTV Installation", 1499),
                    ("Video Doorbell Installation", 699),
                    ("Smart Lock Installation", 699),
                    ("Wi-Fi Setup", 599),
                ],
            },
        ]
        created_services = []
        for row in catalog:
            category, _ = Category.objects.get_or_create(
                name=row["category"],
                defaults={
                    "description": row["description"],
                    "image_url": "",
                },
            )
            if category.description != row["description"]:
                category.description = row["description"]
                category.save(update_fields=["description"])

            for name, base_price in row["services"]:
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

        # Keep old demo-only categories out of customer/provider catalogs.
        Category.objects.filter(name__in=["Home Cleaning", "Repairs"]).update(is_active=False)

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

        support, _ = User.objects.get_or_create(
            username="support1",
            defaults={
                "full_name": "Support Agent",
                "email": "support@example.com",
                "phone": "7777777777",
                "city": "Demo City",
                "role": User.Roles.SUPPORT,
            },
        )
        support.set_password("support12345")
        support.role = User.Roles.SUPPORT
        support.save()

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
        Notification.objects.get_or_create(
            user=support,
            message="Demo support account is ready.",
        )

        self.stdout.write(
            self.style.SUCCESS(
                f"Bootstrap complete. Admin user: {admin.username} (created={created})"
            )
        )
