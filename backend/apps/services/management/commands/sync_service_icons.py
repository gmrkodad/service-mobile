from django.core.management.base import BaseCommand

from apps.services.models import Category, Service


TWEMOJI_BASE = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72"

CATEGORY_ICON_RULES = [
    (("clean",), f"{TWEMOJI_BASE}/1f9fc.png"),  # broom
    (("pest",), f"{TWEMOJI_BASE}/1f41e.png"),  # lady beetle
    (("appliance",), f"{TWEMOJI_BASE}/1f527.png"),  # wrench
    (("electrician",), f"{TWEMOJI_BASE}/1f50c.png"),  # plug
    (("plumber",), f"{TWEMOJI_BASE}/1f6b0.png"),  # tap
    (("carpenter",), f"{TWEMOJI_BASE}/1fa9a.png"),  # carpentry saw
    (("salon",), f"{TWEMOJI_BASE}/1f487.png"),  # haircut
    (("groom",), f"{TWEMOJI_BASE}/1f9d4.png"),  # bearded person
    (("painting",), f"{TWEMOJI_BASE}/1f58c.png"),  # paintbrush
    (("waterproof",), f"{TWEMOJI_BASE}/1f4a7.png"),  # droplet
    (("renovation",), f"{TWEMOJI_BASE}/1f3e0.png"),  # house
    (("packs",), f"{TWEMOJI_BASE}/1f4e6.png"),  # package
    (("shift",), f"{TWEMOJI_BASE}/1f69a.png"),  # truck
    (("water purifier",), f"{TWEMOJI_BASE}/1f6b0.png"),  # tap
    (("smart home",), f"{TWEMOJI_BASE}/1f3e1.png"),  # house with garden
    (("security",), f"{TWEMOJI_BASE}/1f6e1.png"),  # shield
]
CATEGORY_DEFAULT_ICON = f"{TWEMOJI_BASE}/1f9f9.png"  # sponge

SERVICE_ICON_RULES = [
    (("bathroom",), f"{TWEMOJI_BASE}/1f6bd.png"),  # toilet
    (("kitchen",), f"{TWEMOJI_BASE}/1f373.png"),  # cooking
    (("sofa",), f"{TWEMOJI_BASE}/1f6cb.png"),  # couch and lamp
    (("carpet",), f"{TWEMOJI_BASE}/1f9f9.png"),  # sponge
    (("home", "clean"), f"{TWEMOJI_BASE}/1f9fc.png"),  # broom
    (("cockroach",), f"{TWEMOJI_BASE}/1fab3.png"),  # cockroach
    (("termite",), f"{TWEMOJI_BASE}/1f41b.png"),  # bug
    (("mosquito",), f"{TWEMOJI_BASE}/1f99f.png"),  # mosquito
    (("bed bug",), f"{TWEMOJI_BASE}/1f41b.png"),  # bug
    (("ac",), f"{TWEMOJI_BASE}/2744.png"),  # snowflake
    (("washing",), f"{TWEMOJI_BASE}/1f9fa.png"),  # soap
    (("refrigerator",), f"{TWEMOJI_BASE}/1f9ca.png"),  # ice cube
    (("microwave",), f"{TWEMOJI_BASE}/1f37d.png"),  # fork and knife with plate
    (("water purifier",), f"{TWEMOJI_BASE}/1f6b0.png"),  # tap
    (("geyser",), f"{TWEMOJI_BASE}/1f525.png"),  # fire
    (("tv",), f"{TWEMOJI_BASE}/1f4fa.png"),  # television
    (("chimney",), f"{TWEMOJI_BASE}/1f3ed.png"),  # factory
    (("electrician",), f"{TWEMOJI_BASE}/1f50c.png"),  # plug
    (("plumber",), f"{TWEMOJI_BASE}/1f6b0.png"),  # tap
    (("carpenter",), f"{TWEMOJI_BASE}/1fa9a.png"),  # carpentry saw
    (("drill",), f"{TWEMOJI_BASE}/1fa9b.png"),  # screwdriver
    (("switch",), f"{TWEMOJI_BASE}/1f50c.png"),  # plug
    (("socket",), f"{TWEMOJI_BASE}/1f50c.png"),  # plug
    (("tap",), f"{TWEMOJI_BASE}/1f6b0.png"),  # tap
    (("leak",), f"{TWEMOJI_BASE}/1f4a7.png"),  # droplet
    (("door lock",), f"{TWEMOJI_BASE}/1f512.png"),  # lock
    (("women haircut",), f"{TWEMOJI_BASE}/1f487-200d-2640-fe0f.png"),  # woman haircut
    (("manicure",), f"{TWEMOJI_BASE}/1f485.png"),  # nail polish
    (("pedicure",), f"{TWEMOJI_BASE}/1f9b6.png"),  # foot
    (("facial",), f"{TWEMOJI_BASE}/1f9f4.png"),  # lotion bottle
    (("waxing",), f"{TWEMOJI_BASE}/1f9fd.png"),  # sponge
    (("bridal",), f"{TWEMOJI_BASE}/1f470.png"),  # person with veil
    (("spa",), f"{TWEMOJI_BASE}/1f9d6.png"),  # person in steamy room
    (("men haircut",), f"{TWEMOJI_BASE}/1f487-200d-2642-fe0f.png"),  # man haircut
    (("beard",), f"{TWEMOJI_BASE}/1f9d4.png"),  # bearded person
    (("hair color",), f"{TWEMOJI_BASE}/1f9b1.png"),  # curly hair
    (("head massage",), f"{TWEMOJI_BASE}/1f486.png"),  # person getting massage
    (("interior painting",), f"{TWEMOJI_BASE}/1f58c.png"),  # paintbrush
    (("exterior painting",), f"{TWEMOJI_BASE}/1f3e1.png"),  # house with garden
    (("waterproof",), f"{TWEMOJI_BASE}/1f4a7.png"),  # droplet
    (("wall texture",), f"{TWEMOJI_BASE}/1f9f1.png"),  # brick
    (("wood polish",), f"{TWEMOJI_BASE}/1fab5.png"),  # wood
    (("modular kitchen",), f"{TWEMOJI_BASE}/1f373.png"),  # cooking
    (("bathroom renovation",), f"{TWEMOJI_BASE}/1f6bd.png"),  # toilet
    (("false ceiling",), f"{TWEMOJI_BASE}/1f3d7.png"),  # building construction
    (("custom furniture",), f"{TWEMOJI_BASE}/1fa91.png"),  # chair
    (("flooring",), f"{TWEMOJI_BASE}/1f9f1.png"),  # brick
    (("local house shifting",), f"{TWEMOJI_BASE}/1f69a.png"),  # truck
    (("office shifting",), f"{TWEMOJI_BASE}/1f3e2.png"),  # office building
    (("intercity relocation",), f"{TWEMOJI_BASE}/1f5fa.png"),  # world map
    (("packing",), f"{TWEMOJI_BASE}/1f4e6.png"),  # package
    (("ro installation",), f"{TWEMOJI_BASE}/1f6b0.png"),  # tap
    (("annual maintenance",), f"{TWEMOJI_BASE}/1f6e0.png"),  # hammer and wrench
    (("filter replacement",), f"{TWEMOJI_BASE}/1f9ea.png"),  # test tube
    (("breakdown repair",), f"{TWEMOJI_BASE}/1f6e0.png"),  # hammer and wrench
    (("cctv",), f"{TWEMOJI_BASE}/1f4f9.png"),  # video camera
    (("doorbell",), f"{TWEMOJI_BASE}/1f514.png"),  # bell
    (("smart lock",), f"{TWEMOJI_BASE}/1f512.png"),  # lock
    (("wi-fi",), f"{TWEMOJI_BASE}/1f4f6.png"),  # antenna bars
]
SERVICE_DEFAULT_ICON = f"{TWEMOJI_BASE}/1f6e0.png"  # hammer and wrench


def _matches(rule_words, text: str) -> bool:
    return all(word in text for word in rule_words)


def _pick_icon(name: str, rules, default: str) -> str:
    normalized = (name or "").strip().lower()
    for words, url in rules:
        if _matches(words, normalized):
            return url
    return default


def _needs_update(current_url: str, force: bool) -> bool:
    if force:
        return True
    value = (current_url or "").strip().lower()
    return (not value) or ("127.0.0.1" in value) or ("localhost" in value)


class Command(BaseCommand):
    help = "Assign distinct icon URLs to categories/services based on their names."

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Overwrite all existing image_url values.",
        )

    def handle(self, *args, **options):
        force = options["force"]
        updated_categories = 0
        updated_services = 0

        categories = Category.objects.all()
        for category in categories:
            if _needs_update(category.image_url, force):
                category.image_url = _pick_icon(
                    category.name,
                    CATEGORY_ICON_RULES,
                    CATEGORY_DEFAULT_ICON,
                )
                category.save(update_fields=["image_url"])
                updated_categories += 1

        for service in Service.objects.select_related("category").all():
            if _needs_update(service.image_url, force):
                service.image_url = _pick_icon(
                    service.name,
                    SERVICE_ICON_RULES,
                    _pick_icon(
                        service.category.name,
                        CATEGORY_ICON_RULES,
                        SERVICE_DEFAULT_ICON,
                    ),
                )
                service.save(update_fields=["image_url"])
                updated_services += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Updated icons: {updated_categories} categories, {updated_services} services."
            )
        )
