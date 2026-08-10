from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Conversation, ConversationMember, Message, MessageRead

User = get_user_model()


class UserMinimalSerializer(serializers.ModelSerializer):
    """
    Üyeler ve mesaj gönderenler için minimal kullanıcı bilgisi.
    """
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'avatar', 'is_online', 'last_seen')
        read_only_fields = fields


class ConversationMemberSerializer(serializers.ModelSerializer):
    """
    Sohbet üyesi ve kullanıcı bilgilerini paketler.
    """
    user = UserMinimalSerializer(read_only=True)
    user_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), 
        write_only=True, 
        source='user'
    )

    class Meta:
        model = ConversationMember
        fields = ('id', 'conversation', 'user', 'user_id', 'role', 'joined_at')
        read_only_fields = ('id', 'conversation', 'user', 'joined_at')


class MessageSerializer(serializers.ModelSerializer):
    """
    Mesaj geçmişini paketler.
    """
    sender = UserMinimalSerializer(read_only=True)
    read_count = serializers.SerializerMethodField()
    is_read_by_me = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = (
            'id', 
            'conversation', 
            'sender', 
            'client_message_id', 
            'content', 
            'message_type', 
            'created_at', 
            'updated_at', 
            'is_deleted',
            'read_count',
            'is_read_by_me'
        )
        read_only_fields = fields

    def get_read_count(self, obj):
        return obj.read_by.count()

    def get_is_read_by_me(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return obj.read_by.filter(user=request.user).exists()


class ConversationSerializer(serializers.ModelSerializer):
    """
    Sohbet odası detayı, üye listesi ve son mesaj bilgisi.
    """
    members = ConversationMemberSerializer(many=True, read_only=True)
    last_message = serializers.SerializerMethodField()
    
    # Yeni sohbet oluşturma parametreleri (Write-only)
    member_ids = serializers.ListField(
        child=serializers.IntegerField(), 
        write_only=True, 
        required=False
    )

    class Meta:
        model = Conversation
        fields = (
            'id', 
            'type', 
            'name', 
            'created_by', 
            'members', 
            'last_message', 
            'created_at', 
            'updated_at',
            'member_ids'
        )
        read_only_fields = ('id', 'created_by', 'members', 'last_message', 'created_at', 'updated_at')

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by('-created_at').first()
        if last_msg:
            return MessageSerializer(last_msg, context=self.context).data
        return None

    def validate(self, attrs):
        conv_type = attrs.get('type', 'private')
        request_user = self.context['request'].user

        if conv_type == 'private':
            member_ids = set(attrs.get('member_ids', [])) - {request_user.id}
            if len(member_ids) != 1:
                raise serializers.ValidationError({"member_ids": "Özel sohbet tam olarak bir başka kullanıcı içermelidir."})
            target_user_id = member_ids.pop()
            if target_user_id == request_user.id:
                raise serializers.ValidationError({"member_ids": "Kendinizle sohbet başlatamazsınız."})
            if not User.objects.filter(id=target_user_id).exists():
                raise serializers.ValidationError({"member_ids": "Hedef kullanıcı bulunamadı."})

        elif conv_type == 'group':
            name = attrs.get('name')
            if not name or not name.strip():
                raise serializers.ValidationError({"name": "Grup sohbeti için grup adı gereklidir."})
            
            member_ids = attrs.get('member_ids', [])
            # Grubu kuran kişi haricinde seçilen üyelerin kontrolü
            unique_member_ids = set(member_ids) - {request_user.id}
            
            if len(unique_member_ids) + 1 > 5:
                raise serializers.ValidationError({"member_ids": "Bir grup sohbeti en fazla 5 kişiden oluşabilir."})

        return attrs

    def create(self, validated_data):
        conv_type = validated_data.get('type', 'private')
        request_user = self.context['request'].user

        if conv_type == 'private':
            member_ids = set(validated_data.pop('member_ids', [])) - {request_user.id}
            target_user_id = member_ids.pop()
            target_user = User.objects.get(id=target_user_id)

            # Önceden ikisi arasında private bir conversation var mı kontrol et
            existing_conversation = Conversation.objects.filter(
                type='private',
                members__user=request_user
            ).filter(
                members__user=target_user
            ).first()

            if existing_conversation:
                return existing_conversation

            # Yoksa yeni private conversation oluştur
            conversation = Conversation.objects.create(
                type='private',
                created_by=request_user
            )
            # İki kullanıcıyı da üye yap
            ConversationMember.objects.create(conversation=conversation, user=request_user, role='admin')
            ConversationMember.objects.create(conversation=conversation, user=target_user, role='member')
            return conversation

        else: # group
            name = validated_data.get('name')
            member_ids = validated_data.pop('member_ids', [])
            unique_member_ids = set(member_ids) - {request_user.id}

            conversation = Conversation.objects.create(
                type='group',
                name=name,
                created_by=request_user
            )
            # Kuran kullanıcıyı admin yap
            ConversationMember.objects.create(conversation=conversation, user=request_user, role='admin')

            # Diğer seçilen kullanıcıları üye yap
            for user_id in unique_member_ids:
                user = User.objects.filter(id=user_id).first()
                if user:
                    ConversationMember.objects.create(conversation=conversation, user=user, role='member')

            return conversation
