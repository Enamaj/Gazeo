from rest_framework.permissions import BasePermission
from auth_user.models import UserRole


class IsGerant(BasePermission):
    """
    Permission accordée uniquement aux utilisateurs authentifiés ayant le rôle GERANT.
    """
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            request.user.role == UserRole.GERANT
        )


class IsOwnerDepot(BasePermission):
    """
    Permission d'objet accordée uniquement au gérant propriétaire du dépôt concerné.
    """
    def has_object_permission(self, request, view, obj):
        return bool(
            request.user and
            request.user.is_authenticated and
            obj.gerant == request.user
        )

