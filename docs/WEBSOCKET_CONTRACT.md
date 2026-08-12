# WebSocket Contract

## Connection

Development:

ws://localhost:8000/ws/chat/{conversation_id}/?token=ACCESS_TOKEN

Production:

wss://DOMAIN/ws/chat/{conversation_id}/?token=ACCESS_TOKEN

WebSocket bağlantısı authenticated olmalıdır.

---

# Authentication

Client WebSocket bağlantısı oluştururken JWT access token'ı query parameter olarak gönderecektir.
Production ortamında token query parameter ile taşındığı için bağlantı mutlaka `wss://` üzerinden kurulmalıdır.

Örnek:

```text
ws://localhost:8000/ws/chat/3/?token=ACCESS_TOKEN
```

Authentication yöntemi backend ve Flutter tarafında ortak olarak uygulanmalıdır.

Token geçersizse WebSocket bağlantısı kabul edilmemelidir.

Kullanıcı conversation üyesi değilse WebSocket bağlantısı kabul edilmemelidir.

---

# Event Format

Tüm WebSocket mesajları:

{
"type": "event.name",
"data": {}
}

formatında olacaktır.

---

# Client → Server Events

## message.send

Request:

```json
{
  "type": "message.send",
  "data": {
    "client_message_id": "550e8400-e29b-41d4-a716-446655440000",
    "content": "Merhaba",
    "reply_to": 12
  }
}
```

`reply_to` opsiyoneldir ve aynı conversation içindeki mevcut mesajın ID'sidir.
Reply mesajlarında `message.new.data.reply_to`, `id`, `sender`, `content` ve
`message_type` alanlarını içeren küçük bir mesaj özeti olarak döner.

`client_message_id` frontend tarafından üretilen UUID olmalıdır.
Aynı kullanıcı aynı conversation içinde aynı `client_message_id` ile tekrar mesaj gönderirse backend yeni mesaj oluşturmamalı, mevcut mesaj için tekrar `message.ack` dönmelidir.

Backend:

1. Kullanıcı authenticated mı kontrol eder.
2. Kullanıcı conversation üyesi mi kontrol eder.
3. `client_message_id` geçerli UUID mi kontrol eder.
4. Content boş mu kontrol eder.
5. Aynı `client_message_id` daha önce kaydedilmiş mi kontrol eder.
6. Message database'e kaydedilir.
7. Önce gönderen client'a `message.ack` gönderilir.
8. Ardından `message.new` event'i room'a gönderilir.

---

# typing.start

Request:

```json
{
  "type": "typing.start",
  "data": {}
}
```

Server:

```json
{
  "type": "typing.start",
  "data": {
    "user_id": 1,
    "username": "user1"
  }
}
```

Typing event'i gönderen kullanıcı dışındaki room üyelerine gönderilmelidir.

---

# typing.stop

Request:

```json
{
  "type": "typing.stop",
  "data": {}
}
```

Server:

```json
{
  "type": "typing.stop",
  "data": {
    "user_id": 1
  }
}
```

---

# message.read

Request:

```json
{
  "type": "message.read",
  "data": {
    "message_id": 15
  }
}
```

`message.read` idempotent olmalıdır.
Aynı kullanıcı aynı message için tekrar read event'i gönderirse backend yeni kayıt oluşturmamalı, mevcut read bilgisini dönmelidir.

Server:

```json
{
  "type": "message.read",
  "data": {
    "message_id": 15,
    "user_id": 2,
    "read_at": "2026-08-10T10:35:00Z",
    "read_count": 1,
    "recipient_count": 2,
    "is_read_by_all": false
  }
}
```

---

# Server → Client Events

## message.new

```json
{
  "type": "message.new",
  "data": {
    "id": 15,
    "client_message_id": "550e8400-e29b-41d4-a716-446655440000",
    "conversation_id": 3,
    "sender": {
      "id": 1,
      "username": "user1",
      "avatar": null
    },
    "reply_to": {
      "id": 12,
      "sender": {"id": 2, "username": "user2", "avatar": null},
      "content": "Yarın geliyor musun?",
      "message_type": "text"
    },
    "content": "Merhaba",
    "message_type": "text",
    "created_at": "2026-08-10T10:30:00Z"
  }
}
```

---

# message.ack

`message.ack` yalnızca mesajı gönderen client'a gönderilir.
Frontend pending mesajı bu event ile confirmed hale getirir.

```json
{
  "type": "message.ack",
  "data": {
    "client_message_id": "550e8400-e29b-41d4-a716-446655440000",
    "message_id": 15,
    "conversation_id": 3,
    "created_at": "2026-08-10T10:30:00Z"
  }
}
```

---

# typing.start

```json
{
  "type": "typing.start",
  "data": {
    "user_id": 1,
    "username": "user1"
  }
}
```

---

# typing.stop

```json
{
  "type": "typing.stop",
  "data": {
    "user_id": 1
  }
}
```

---

# message.read

```json
{
  "type": "message.read",
  "data": {
    "message_id": 15,
    "user_id": 2,
    "read_at": "2026-08-10T10:35:00Z",
    "read_count": 2,
    "recipient_count": 2,
    "is_read_by_all": true
  }
}
```

Frontend, okunma tikini yalnizca `is_read_by_all` degeri `true` oldugunda
mavi gosterir. Grup sohbetinde bu alan ancak `read_count` degeri gonderen
haric tum alicilari ifade eden `recipient_count` degerine ulastiginda `true`
olur.

---

# user.online

```json
{
  "type": "user.online",
  "data": {
    "user_id": 1,
    "username": "user1"
  }
}
```

---

# user.offline

```json
{
  "type": "user.offline",
  "data": {
    "user_id": 1,
    "username": "user1",
    "last_seen": "2026-08-10T10:40:00Z"
  }
}
```

---

# error

```json
{
  "type": "error",
  "data": {
    "code": "NOT_MEMBER",
    "message": "You are not a member of this conversation."
  }
}
```

Error codes:

INVALID_TOKEN
NOT_MEMBER
MESSAGE_EMPTY
MESSAGE_TOO_LONG
CLIENT_MESSAGE_ID_REQUIRED
CLIENT_MESSAGE_ID_INVALID
MESSAGE_NOT_FOUND
INVALID_EVENT
PERMISSION_DENIED
INTERNAL_ERROR

---

# Reconnection

WebSocket bağlantısı koparsa frontend otomatik reconnect denemelidir.

Önerilen reconnect davranışı:

1. Bağlantı kopunca typing state temizlenir.
2. Frontend exponential backoff ile tekrar bağlanır.
3. Reconnect başarılı olunca frontend son bilinen mesaj id'sinden sonraki mesajları REST ile çeker.
4. Kaçan mesajlar UI'a eklendikten sonra canlı WebSocket eventleri dinlenmeye devam edilir.
5. Pending mesaj varsa aynı `client_message_id` ile tekrar `message.send` gönderilebilir.

Reconnect sonrası mesaj senkronizasyonu:

```text
GET /conversations/{id}/messages/?after_id=15
```

Eski mesajları sayfalı çekmek için:

```text
GET /conversations/{id}/messages/?before_id=15&page_size=30
```

Frontend aynı `message.id` veya aynı `client_message_id` ile gelen mesajları UI'da duplicate göstermemelidir.

---

# WebSocket Rules

Polling kullanılmayacaktır.

Mesaj gönderme REST API üzerinden yapılmayacaktır.

Mesaj önce database'e kaydedilecek, ardından room'a broadcast edilecektir.

Typing eventleri database'e kaydedilmeyecektir.

Online/offline state Redis + database ile yönetilebilir.

Kullanıcı birden fazla cihazdan bağlanabilir.

Kullanıcı yalnızca tüm WebSocket bağlantıları kapandığında offline kabul edilmelidir.
