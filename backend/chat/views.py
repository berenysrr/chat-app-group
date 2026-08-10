from rest_framework import viewsets, generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404
from django.contrib.auth import get_user_model

from .models import Conversation, ConversationMember, Message
from .serializers import (
    ConversationSerializer, 
    ConversationMemberSerializer, 
    MessageSerializer
)
from .permissions import IsConversationMember, IsConversationAdmin

User = get_user_model()


class MessagePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class ConversationViewSet(viewsets.ModelViewSet):
    """
    Sohbet odalarını listeleme, detay görme, oluşturma ve silme API'si.
    """
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated, IsConversationMember]

    def get_queryset(self):
        # Yalnızca istek atan kullanıcının üye olduğu sohbetleri getir
        return Conversation.objects.filter(
            members__user=self.request.user
        ).distinct().order_by('-updated_at')

    def perform_create(self, serializer):
        serializer.save()

    def list(self, request, *args, **kwargs):
        serializer = self.get_serializer(self.get_queryset(), many=True)
        return Response({"results": serializer.data})

    def get_permissions(self):
        if self.action in ('update', 'partial_update'):
            return [permissions.IsAuthenticated(), IsConversationAdmin()]
        return [permissions.IsAuthenticated(), IsConversationMember()]

    def perform_update(self, serializer):
        if serializer.instance.type != 'group':
            raise PermissionDenied("Yalnızca grup sohbetinin adı güncellenebilir.")
        if set(serializer.validated_data) - {'name'}:
            raise ValidationError({"detail": "Yalnızca grup adı güncellenebilir."})
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        conversation = self.get_object()
        member = ConversationMember.objects.filter(conversation=conversation, user=request.user).first()
        if not member:
            return Response({"detail": "Bu sohbetin üyesi değilsiniz."}, status=status.HTTP_403_FORBIDDEN)

        if conversation.type == 'group' and member.role != 'admin':
            # Normal üye silme işlemi yaparsa sadece gruptan ayrılır
            member.delete()
            return Response({"detail": "Gruptan ayrıldınız."}, status=status.HTTP_200_OK)

        conversation.delete()
        return Response({"detail": "Sohbet silindi."}, status=status.HTTP_204_NO_CONTENT)


class ConversationMembersView(APIView):
    """
    Sohbet üyelerini listeleme, gruba yeni üye ekleme ve üye çıkarma API'si.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_conversation(self, conversation_id, user):
        conversation = get_object_or_404(Conversation, id=conversation_id)
        if not ConversationMember.objects.filter(conversation=conversation, user=user).exists():
            return None, Response({"detail": "Bu sohbetin üyesi değilsiniz."}, status=status.HTTP_403_FORBIDDEN)
        return conversation, None

    def get(self, request, conversation_id):
        conversation, error_response = self.get_conversation(conversation_id, request.user)
        if error_response:
            return error_response

        members = conversation.members.all().order_by('joined_at')
        serializer = ConversationMemberSerializer(members, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, conversation_id):
        conversation, error_response = self.get_conversation(conversation_id, request.user)
        if error_response:
            return error_response

        if conversation.type != 'group':
            return Response({"detail": "Yalnızca grup sohbetlerine üye eklenebilir."}, status=status.HTTP_400_BAD_REQUEST)

        # Sadece admin üye ekleyebilir
        admin_member = ConversationMember.objects.filter(conversation=conversation, user=request.user, role='admin').first()
        if not admin_member:
            return Response({"detail": "Gruba üye ekleme yetkiniz yok. Sadece admin ekleyebilir."}, status=status.HTTP_403_FORBIDDEN)

        user_id = request.data.get('user_id')
        if not user_id:
            return Response({"detail": "Eklemek istediğiniz kullanıcı ID'si (user_id) gereklidir."}, status=status.HTTP_400_BAD_REQUEST)

        target_user = User.objects.filter(id=user_id).first()
        if not target_user:
            return Response({"detail": "Kullanıcı bulunamadı."}, status=status.HTTP_404_NOT_FOUND)

        if ConversationMember.objects.filter(conversation=conversation, user=target_user).exists():
            return Response({"detail": "Bu kullanıcı zaten grupta ekli."}, status=status.HTTP_400_BAD_REQUEST)

        if conversation.members.count() >= 5:
            return Response({"detail": "Grup sohbeti maksimum 5 kişiden oluşabilir."}, status=status.HTTP_400_BAD_REQUEST)

        new_member = ConversationMember.objects.create(conversation=conversation, user=target_user, role='member')
        return Response(ConversationMemberSerializer(new_member).data, status=status.HTTP_201_CREATED)

    def delete(self, request, conversation_id, user_id=None):
        conversation, error_response = self.get_conversation(conversation_id, request.user)
        if error_response:
            return error_response

        if conversation.type != 'group':
            return Response({"detail": "Yalnızca grup sohbetlerinden üye çıkarılabilir."}, status=status.HTTP_400_BAD_REQUEST)

        if not user_id:
            return Response({"detail": "Çıkarılacak kullanıcı ID'si gereklidir."}, status=status.HTTP_400_BAD_REQUEST)

        target_member = ConversationMember.objects.filter(conversation=conversation, user_id=user_id).first()
        if not target_member:
            return Response({"detail": "Üye bulunamadı."}, status=status.HTTP_404_NOT_FOUND)

        request_member = ConversationMember.objects.filter(conversation=conversation, user=request.user).first()
        
        # Kullanıcı kendisini gruptan çıkarabilir (Ayrılma) VEYA Admin bir başkasını çıkarabilir
        if request.user.id != int(user_id) and request_member.role != 'admin':
            return Response({"detail": "Başka bir üyeyi çıkarmak için admin olmalısınız."}, status=status.HTTP_403_FORBIDDEN)

        target_member.delete()
        return Response({"detail": "Üye gruptan çıkarıldı."}, status=status.HTTP_200_OK)


class ConversationMessageHistoryView(generics.ListAPIView):
    """
    Sohbet odasına ait geçmiş mesajları sayfalama (Pagination) ile getiren API.
    NOT: POST (mesaj atma) endpoint'i burada yoktur. Mesaj atma WebSocket üzerinden yapılır.
    """
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = MessagePagination

    def get_queryset(self):
        conversation_id = self.kwargs.get('conversation_id')
        conversation = get_object_or_404(Conversation, id=conversation_id)

        # Kullanıcının oda üyesi olup olmadığını doğrula
        if not ConversationMember.objects.filter(conversation=conversation, user=self.request.user).exists():
            return Message.objects.none()

        messages = conversation.messages.filter(is_deleted=False)
        after_id = self.request.query_params.get('after_id')
        before_id = self.request.query_params.get('before_id')
        if after_id:
            messages = messages.filter(id__gt=after_id)
        if before_id:
            messages = messages.filter(id__lt=before_id)
        return messages.order_by('-created_at')
