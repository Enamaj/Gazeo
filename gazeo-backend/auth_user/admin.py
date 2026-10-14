from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('telephone', 'username', 'role', 'is_verified', 'points_fidelite', 'is_staff', 'date_joined')
    list_filter = ('role', 'is_verified', 'is_staff', 'is_active')
    search_fields = ('telephone', 'username', 'email')
    ordering = ('-date_joined',)
    fieldsets = (
        (None, {'fields': ('telephone', 'password')}),
        ('Informations personnelles', {'fields': ('username', 'first_name', 'last_name', 'email')}),
        ('Rôles & Privilèges GAZEO', {'fields': ('role', 'is_verified', 'points_fidelite', 'fcm_token')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Dates importantes', {'fields': ('last_login', 'date_joined')}),
    )
