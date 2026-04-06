from django.contrib import admin

from .models import Category, ProviderServicePrice, Service

admin.site.register(Category)
admin.site.register(Service)
admin.site.register(ProviderServicePrice)

