from django.db import models
from django.conf import settings

# 1. Sohbet Odası Modeli (Özel veya Grup)
class Conversation(models.Model):
    TYPE_CHOICES = (
        ('private', 'Private'),
        ('group', 'Group'),
    )
    type = models.CharField(max_length=10, choices=TYPE_CHOICES, default='private')
    name = models.CharField(max_length=255, null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_conversations'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.type} - {self.name or self.id}"


# 2. Sohbet Üyesi Modeli
class ConversationMember(models.Model):
    ROLE_CHOICES = (
        ('admin', 'Admin'),
        ('member', 'Member'),
    )
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='members'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='conversations'
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='member')
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # Bir kullanıcı aynı sohbete 2 kez eklenemez
        constraints = [
            models.UniqueConstraint(fields=['conversation', 'user'], name='unique_conversation_member')
        ]

    def __str__(self):
        return f"{self.user.username} in conversation {self.conversation.id}"


# 3. Mesaj Modeli
class Message(models.Model):
    TYPE_CHOICES = (
        ('text', 'Text'),
    )
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages'
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_messages'
    )
    client_message_id = models.CharField(max_length=255, null=True, blank=True)
    content = models.TextField()
    message_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default='text')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    class Meta:
        ordering = ['created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['conversation', 'sender', 'client_message_id'],
                name='unique_client_message_per_sender',
                condition=models.Q(client_message_id__isnull=False)
            )
        ]

    def __str__(self):
        return f"Message {self.id} by {self.sender.username}"


# 4. Mesaj Okundu Bilgisi Modeli
class MessageRead(models.Model):
    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name='read_by'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='read_messages'
    )
    read_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # Bir kullanıcı aynı mesaj için sadece 1 okundu kaydı oluşturabilir
        constraints = [
            models.UniqueConstraint(fields=['message', 'user'], name='unique_message_read')
        ]

    def __str__(self):
        return f"{self.user.username} read message {self.message.id}"