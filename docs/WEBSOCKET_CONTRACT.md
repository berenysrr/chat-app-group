# WebSocket Contract

## Connection

Development:

ws://localhost:8000/ws/chat/{conversation_id}/

Production:

wss://DOMAIN/ws/chat/{conversation_id}/

WebSocket bağlantısı authenticated olmalıdır.

---

# Authentication

Client WebSocket bağlantısı oluştururken JWT access token gönderecektir.

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

{
"type": "message.send",
"data": {
"content": "Merhaba"
}
}

Backend:

1. Kullanıcı authenticated mı kontrol eder.
2. Kullanıcı conversation üyesi mi kontrol eder.
3. Content boş mu kontrol eder.
4. Message database'e kaydedilir.
5. message.new event'i room'a gönderilir.

---

# typing.start

Request:

{
"type": "typing.start",
"data": {}
}

Server:

{
"type": "typing.start",
"data": {
"user_id": 1,
"username": "user1"
}
}

Typing event'i gönderen kullanıcı dışındaki room üyelerine gönderilmelidir.

---

# typing.stop

Request:

{
"type": "typing.stop",
"data": {}
}

Server:

{
"type": "typing.stop",
"data": {
"user_id": 1
}
}

---

# message.read

Request:

{
"type": "message.read",
"data": {
"message_id": 15
}
}

Server:

{
"type": "message.read",
"data": {
"message_id": 15,
"user_id": 2,
"read_at": "2026-08-10T10:35:00Z"
}
}

---

# Server → Client Events

## message.new

{
"type": "message.new",
"data": {
"id": 15,
"conversation_id": 3,
"sender": {
"id": 1,
"username": "user1",
"avatar": null
},
"content": "Merhaba",
"message_type": "text",
"created_at": "2026-08-10T10:30:00Z"
}
}

---

# typing.start

{
"type": "typing.start",
"data": {
"user_id": 1,
"username": "user1"
}
}

---

# typing.stop

{
"type": "typing.stop",
"data": {
"user_id": 1
}
}

---

# message.read

{
"type": "message.read",
"data": {
"message_id": 15,
"user_id": 2,
"read_at": "2026-08-10T10:35:00Z"
}
}

---

# user.online

{
"type": "user.online",
"data": {
"user_id": 1,
"username": "user1"
}
}

---

# user.offline

{
"type": "user.offline",
"data": {
"user_id": 1,
"username": "user1",
"last_seen": "2026-08-10T10:40:00Z"
}
}

---

# error

{
"type": "error",
"data": {
"code": "NOT_MEMBER",
"message": "You are not a member of this conversation."
}
}

Error codes:

INVALID_TOKEN
NOT_MEMBER
MESSAGE_EMPTY
MESSAGE_TOO_LONG
MESSAGE_NOT_FOUND
INVALID_EVENT
PERMISSION_DENIED
INTERNAL_ERROR

---

# WebSocket Rules

Polling kullanılmayacaktır.

Mesaj gönderme REST API üzerinden yapılmayacaktır.

Mesaj önce database'e kaydedilecek, ardından room'a broadcast edilecektir.

Typing eventleri database'e kaydedilmeyecektir.

Online/offline state Redis + database ile yönetilebilir.

Kullanıcı birden fazla cihazdan bağlanabilir.

Kullanıcı yalnızca tüm WebSocket bağlantıları kapandığında offline kabul edilmelidir.
