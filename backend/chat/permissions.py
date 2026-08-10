from rest_framework import permissions
from .models import ConversationMember, Conversation

class IsConversationMember(permissions.BasePermission):
    """
    Yalnızca sohbet odasının üyesi olan kullanıcıların erişimine izin verir.
    """

    def has_permission(self, request, view):
        # Kullanıcının giriş yapmış (authenticated) olması zorunludur
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        # Erişilmeye çalışılan nesneden Conversation nesnesini tespit ediyoruz
        if isinstance(obj, Conversation):
            conversation = obj
        elif hasattr(obj, 'conversation'):
            conversation = obj.conversation
        else:
            return False

        # İstek atan kullanıcı bu odanın üyesi mi?
        return ConversationMember.objects.filter(
            conversation=conversation, 
            user=request.user
        ).exists()


class IsConversationAdmin(permissions.BasePermission):
    """
    Yalnızca grubun yöneticisi (admin) olan kullanıcıların erişimine izin verir.
    (Grup adını değiştirme veya üye çıkarma gibi işlemler için kullanılır).
    """

    def has_object_permission(self, request, view, obj):
        if isinstance(obj, Conversation):
            conversation = obj
        elif hasattr(obj, 'conversation'):
            conversation = obj.conversation
        else:
            return False

        return ConversationMember.objects.filter(
            conversation=conversation, 
            user=request.user,
            role='admin'
        ).exists()
