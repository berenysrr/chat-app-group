from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket bağlantılarını yöneten, gelen event'leri karşılayan
    ve oda üyelerine yayınlayan (broadcast) ana Consumer sınıfı.
    """

    async def connect(self):
        self.user = self.scope.get("user")
        self.conversation_id = self.scope["url_route"]["kwargs"].get("conversation_id")
        self.room_group_name = f"chat_{self.conversation_id}"

        # 1. Kullanıcı doğrulanmamışsa (Anonimse) bağlantıyı reddet
        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return

        # 2. Odaya (Redis Grubuna) Katıl
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        # 3. Bağlantıyı kabul et
        await self.accept()

        # 4. Odadaki diğer kişilere kullanıcının online olduğunu bildir
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "user_online_event",
                "user_id": self.user.id,
                "username": self.user.username,
            }
        )

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            # 1. Odadaki diğer kişilere kullanıcının offline olduğunu bildir
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "user_offline_event",
                    "user_id": self.user.id,
                    "username": self.user.username,
                    "last_seen": timezone.now().isoformat(),
                }
            )

            # 2. Odedan (Redis Grubundan) Çık
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    async def receive_json(self, content):
        """
        Client'tan gelen JSON paketlerini dinler ve türüne göre yönlendirir.
        Gelen zarf formatı: { "type": "event.name", "data": {...} }
        """
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
            # Geçersiz event türü hatası dön
            await self.send_json({
                "type": "error",
                "data": {
                    "code": "INVALID_EVENT",
                    "message": f"Unknown event type: {event_type}"
                }
            })

    # --- HANDLER FONKSİYONLARI ---

    async def handle_message_send(self, data):
        content = data.get("content", "").strip()

        if not content:
            await self.send_json({
                "type": "error",
                "data": {"code": "MESSAGE_EMPTY", "message": "Message content cannot be empty."}
            })
            return

        # Geçici (Mock) mesaj yayınlama - Kişi 2 modelleri bitirince DB servisine bağlayacağız
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "chat_message_event",
                "message_data": {
                    "id": 1,
                    "conversation_id": int(self.conversation_id),
                    "sender": {
                        "id": self.user.id,
                        "username": self.user.username,
                        "avatar": None,
                    },
                    "content": content,
                    "message_type": "text",
                    "created_at": timezone.now().isoformat(),
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
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "message_read_event",
                "message_id": message_id,
                "user_id": self.user.id,
                "read_at": timezone.now().isoformat(),
            }
        )

    # --- REDIS EVENT BROADCAST EVENTLERİ ---

    async def chat_message_event(self, event):
        await self.send_json({
            "type": "message.new",
            "data": event["message_data"]
        })

    async def typing_start_event(self, event):
        # Gönderen kişinin kendisine tekrar "yazıyorsun" haberi gitmesin
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