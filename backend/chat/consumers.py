from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from uuid import UUID
from .models import Conversation, ConversationMember, Message, MessageRead
from accounts.models import User

ALLOWED_MESSAGE_TYPES = {'text', 'audio'}


# --- VERİTABANI İŞLEMLERİ (DATABASE HELPERS) ---

@database_sync_to_async
def is_user_member(user_id, conversation_id):
    """Kullanıcı sohbet odasının gerçek üyesi mi kontrol eder."""
    return ConversationMember.objects.filter(
        conversation_id=conversation_id,
        user_id=user_id
    ).exists()


@database_sync_to_async
def save_message_to_db(
    user,
    conversation_id,
    content,
    client_message_id,
    message_type='text',
    reply_to_id=None,
):
    """Gelen mesajı PostgreSQL/SQLite veritabanına kaydeder."""
    existing = Message.objects.filter(
        conversation_id=conversation_id,
        sender=user,
        client_message_id=client_message_id,
    ).first()
    if existing is not None:
        return existing, False
    reply_to = None
    if reply_to_id is not None:
        reply_to = Message.objects.filter(
            id=reply_to_id,
            conversation_id=conversation_id,
            is_deleted=False,
        ).select_related('sender').first()
        if reply_to is None:
            return None, False
    message, created = Message.objects.get_or_create(
        conversation_id=conversation_id,
        sender=user,
        client_message_id=client_message_id,
        defaults={
            'content': content,
            'message_type': message_type,
            'reply_to': reply_to,
        },
    )
    if created:
        Conversation.objects.filter(id=conversation_id).update(
            updated_at=timezone.now()
        )
    return message, created


@database_sync_to_async
def save_message_read_to_db(user, message_id, conversation_id):
    """Okundu bilgisini veritabanına yazar."""
    message = Message.objects.filter(
        id=message_id,
        conversation_id=conversation_id,
        conversation__members__user=user,
        is_deleted=False,
    ).first()
    if message is None or message.sender_id == user.id:
        return None
    obj, _ = MessageRead.objects.get_or_create(message=message, user=user)
    recipient_count = ConversationMember.objects.filter(
        conversation_id=conversation_id,
    ).exclude(user_id=message.sender_id).count()
    read_count = MessageRead.objects.filter(
        message=message,
        user__conversations__conversation_id=conversation_id,
    ).exclude(user_id=message.sender_id).values('user_id').distinct().count()
    return {
        'read_at': obj.read_at.isoformat(),
        'read_count': read_count,
        'recipient_count': recipient_count,
        'is_read_by_all': recipient_count > 0 and read_count >= recipient_count,
    }


@database_sync_to_async
def get_reply_payload(message_id):
    message = Message.objects.select_related('reply_to__sender').get(id=message_id)
    replied = message.reply_to
    if replied is None:
        return None
    return {
        "id": replied.id,
        "sender": {
            "id": replied.sender.id,
            "username": replied.sender.username,
            "avatar": replied.sender.avatar.url if replied.sender.avatar else None,
        },
        "content": replied.content,
        "message_type": replied.message_type,
    }


@database_sync_to_async
def set_user_online_status(user_id, is_online):
    """Kullanıcının online/offline durumunu User tablosunda günceller."""
    update_fields = {
        'is_online': is_online,
        'last_seen': timezone.now(),
    }
    User.objects.filter(id=user_id).update(**update_fields)


# --- CONSUMER SINIFI ---

class ChatConsumer(AsyncJsonWebsocketConsumer):

    async def connect(self):
        self.user = self.scope.get("user")
        self.conversation_id = self.scope["url_route"]["kwargs"].get("conversation_id")
        self.room_group_name = f"chat_{self.conversation_id}"

        # 1. Anonim kullanıcı engellemesi
        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return

        # 2. Gerçek Veritabanı Üyelik Kontrolü
        is_member = await is_user_member(self.user.id, self.conversation_id)
        if not is_member:
            await self.close(code=4003)  # Üye değilse reddet
            return

        # 3. Redis Grubuna Ekle
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

        # 4. Veritabanında Kullanıcıyı Online Yap
        await set_user_online_status(self.user.id, True)

        # 5. Odadakilere Online Duyurusu Yap
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "user_online_event",
                "user_id": self.user.id,
                "username": self.user.username,
            }
        )

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name") and self.user and not self.user.is_anonymous:
            # 1. Veritabanında Kullanıcıyı Offline Yap & last_seen Güncelle
            await set_user_online_status(self.user.id, False)

            # 2. Odadakilere Offline Duyurusu Yap
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "user_offline_event",
                    "user_id": self.user.id,
                    "username": self.user.username,
                    "last_seen": timezone.now().isoformat(),
                }
            )

            # 3. Redis Grubundan Çıkar
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    async def receive_json(self, content):
        event_type = content.get("type")
        data = content.get("data", {})

        if event_type == "ping":
            await self.send_json({"type": "pong"})
        elif event_type == "message.send":
            await self.handle_message_send(data)
        elif event_type == "typing.start":
            await self.handle_typing_start()
        elif event_type == "typing.stop":
            await self.handle_typing_stop()
        elif event_type == "message.read":
            await self.handle_message_read(data)
        else:
            await self.send_json({

                "type": "error",
                "data": {
                    "code": "INVALID_EVENT",
                    "message": f"Unknown event type: {event_type}"
                }
            })

    # --- HANDLERS ---

    async def handle_message_send(self, data):
        raw_content = data.get("content", "")
        content = raw_content.strip() if isinstance(raw_content, str) else ""
        client_message_id = data.get("client_message_id")
        message_type = str(data.get("message_type") or 'text').strip().lower()
        reply_to_id = data.get("reply_to")

        if not client_message_id:
            await self.send_json({"type": "error", "data": {"code": "CLIENT_MESSAGE_ID_REQUIRED", "message": "client_message_id is required."}})
            return
        try:
            UUID(str(client_message_id))
        except (ValueError, TypeError, AttributeError):
            await self.send_json({"type": "error", "data": {"code": "CLIENT_MESSAGE_ID_INVALID", "message": "client_message_id must be a UUID."}})
            return

        if message_type not in ALLOWED_MESSAGE_TYPES:
            await self.send_json({
                "type": "error",
                "data": {
                    "code": "MESSAGE_TYPE_INVALID",
                    "message": f"Unsupported message_type: {message_type}",
                }
            })
            return

        if not content:
            await self.send_json({
                "type": "error",
                "data": {"code": "MESSAGE_EMPTY", "message": "Message content cannot be empty."}
            })
            return

        if reply_to_id is not None:
            try:
                reply_to_id = int(reply_to_id)
                if reply_to_id <= 0:
                    raise ValueError
            except (TypeError, ValueError):
                await self.send_json({
                    "type": "error",
                    "data": {
                        "code": "REPLY_TO_INVALID",
                        "message": "reply_to must be a positive message id.",
                    }
                })
                return

        if message_type == 'audio':
            if not content.startswith('data:audio/'):
                await self.send_json({
                    "type": "error",
                    "data": {
                        "code": "AUDIO_PAYLOAD_INVALID",
                        "message": "Audio messages must be sent as a data:audio/* payload.",
                    }
                })
                return
            if len(content) > 2_500_000:
                await self.send_json({
                    "type": "error",
                    "data": {
                        "code": "AUDIO_TOO_LARGE",
                        "message": "Audio payload is too large.",
                    }
                })
                return

        # GERÇEK VERİTABANINA MESAJI KAYDET
        msg, created = await save_message_to_db(
            self.user,
            int(self.conversation_id),
            content,
            client_message_id,
            message_type,
            reply_to_id,
        )

        if msg is None:
            await self.send_json({
                "type": "error",
                "data": {
                    "code": "REPLY_TO_NOT_FOUND",
                    "message": "Reply message was not found in this conversation.",
                }
            })
            return

        await self.send_json({
            "type": "message.ack",
            "data": {
                "client_message_id": client_message_id,
                "message_id": msg.id,
                "conversation_id": int(self.conversation_id),
                "created_at": msg.created_at.isoformat(),
            },
        })
        if not created:
            return

        reply_payload = await get_reply_payload(msg.id)

        # GERÇEK VERİTABANI MESAJ BİLGİSİ İLE ROOM'A YAYINLA
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "chat_message_event",
                "message_data": {
                    "id": msg.id,  # Gerçek DB mesaj ID'si
                    "client_message_id": client_message_id,
                    "conversation_id": int(self.conversation_id),
                    "sender": {
                        "id": self.user.id,
                        "username": self.user.username,
                        "avatar": self.user.avatar.url if self.user.avatar else None,
                    },
                    "reply_to": reply_payload,
                    "content": msg.content,
                    "message_type": msg.message_type,
                    "created_at": msg.created_at.isoformat(),
                }
            }
        )

    async def handle_typing_start(self):
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "typing_start_event",
                "sender_id": self.user.id,
                "user_id": self.user.id,
                "username": self.user.username,
            }
        )

    async def handle_typing_stop(self):
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "typing_stop_event",
                "sender_id": self.user.id,
                "user_id": self.user.id,
            }
        )

    async def handle_message_read(self, data):
        message_id = data.get("message_id")
        if not message_id:
            return

        # GERÇEK VERİTABANINA OKUNDU BİLGİSİNİ KAYDET
        receipt = await save_message_read_to_db(
            self.user,
            message_id,
            int(self.conversation_id),
        )
        if receipt is None:
            return

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "message_read_event",
                "message_id": message_id,
                "user_id": self.user.id,
                "read_at": receipt["read_at"],
                "read_count": receipt["read_count"],
                "recipient_count": receipt["recipient_count"],
                "is_read_by_all": receipt["is_read_by_all"],
            }
        )

    # --- BROADCAST EVENTS ---

    async def chat_message_event(self, event):
        await self.send_json({
            "type": "message.new",
            "data": event["message_data"]
        })

    async def typing_start_event(self, event):
        if event["sender_id"] != self.user.id:
            await self.send_json({
                "type": "typing.start",
                "data": {
                    "user_id": event["user_id"],
                    "username": event["username"]
                }
            })

    async def typing_stop_event(self, event):
        if event["sender_id"] != self.user.id:
            await self.send_json({
                "type": "typing.stop",
                "data": {
                    "user_id": event["user_id"]
                }
            })

    async def message_read_event(self, event):
        await self.send_json({
            "type": "message.read",
            "data": {
                "message_id": event["message_id"],
                "user_id": event["user_id"],
                "read_at": event["read_at"],
                "read_count": event["read_count"],
                "recipient_count": event["recipient_count"],
                "is_read_by_all": event["is_read_by_all"],
            }
        })

    async def user_online_event(self, event):
        await self.send_json({
            "type": "user.online",
            "data": {
                "user_id": event["user_id"],
                "username": event["username"]
            }
        })

    async def user_offline_event(self, event):
        await self.send_json({
            "type": "user.offline",
            "data": {
                "user_id": event["user_id"],
                "username": event["username"],
                "last_seen": event["last_seen"]
            }
        })
