from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from uuid import UUID
from .models import ConversationMember, Message, MessageRead
from accounts.models import User


# --- VERİTABANI İŞLEMLERİ (DATABASE HELPERS) ---

@database_sync_to_async
def is_user_member(user_id, conversation_id):
    """Kullanıcı sohbet odasının gerçek üyesi mi kontrol eder."""
    return ConversationMember.objects.filter(
        conversation_id=conversation_id,
        user_id=user_id
    ).exists()


@database_sync_to_async
def save_message_to_db(user, conversation_id, content, client_message_id):
    """Gelen mesajı PostgreSQL/SQLite veritabanına kaydeder."""
    message, created = Message.objects.get_or_create(
        conversation_id=conversation_id,
        sender=user,
        client_message_id=client_message_id,
        defaults={'content': content, 'message_type': 'text'},
    )
    return message, created


@database_sync_to_async
def save_message_read_to_db(user, message_id):
    """Okundu bilgisini veritabanına yazar."""
    obj, created = MessageRead.objects.get_or_create(
        message_id=message_id,
        user=user
    )
    return obj.read_at.isoformat()


@database_sync_to_async
def set_user_online_status(user_id, is_online):
    """Kullanıcının online/offline durumunu User tablosunda günceller."""
    update_fields = {'is_online': is_online}
    if not is_online:
        update_fields['last_seen'] = timezone.now()
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

        if event_type == "message.send":
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
        content = data.get("content", "").strip()
        client_message_id = data.get("client_message_id")

        if not client_message_id:
            await self.send_json({"type": "error", "data": {"code": "CLIENT_MESSAGE_ID_REQUIRED", "message": "client_message_id is required."}})
            return
        try:
            UUID(str(client_message_id))
        except (ValueError, TypeError, AttributeError):
            await self.send_json({"type": "error", "data": {"code": "CLIENT_MESSAGE_ID_INVALID", "message": "client_message_id must be a UUID."}})
            return

        if not content:
            await self.send_json({
                "type": "error",
                "data": {"code": "MESSAGE_EMPTY", "message": "Message content cannot be empty."}
            })
            return

        # GERÇEK VERİTABANINA MESAJI KAYDET
        msg, created = await save_message_to_db(self.user, int(self.conversation_id), content, client_message_id)

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
        read_at_str = await save_message_read_to_db(self.user, message_id)

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "message_read_event",
                "message_id": message_id,
                "user_id": self.user.id,
                "read_at": read_at_str,
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
                "read_at": event["read_at"]
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
