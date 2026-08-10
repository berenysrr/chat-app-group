# REST API Contract

Base URL:

`http://localhost:8000/api/`

Production URL daha sonra belirlenecektir.

---

# Authentication

## Register

`POST /auth/register/`

Request:

```json
{
  "username": "user1",
  "email": "user@example.com",
  "password": "Password123"
}
```

Response:

```json
{
  "message": "User registered successfully",
  "access": "ACCESS_TOKEN",
  "refresh": "REFRESH_TOKEN",
  "user": {
    "id": 1,
    "username": "user1",
    "email": "user@example.com"
  }
}
```

---

# Login

`POST /auth/login/`

Request:

```json
{
  "username": "user1",
  "password": "Password123"
}
```

Response:

```json
{
  "access": "ACCESS_TOKEN",
  "refresh": "REFRESH_TOKEN",
  "user": {
    "id": 1,
    "username": "user1",
    "email": "user@example.com",
    "avatar": null
  }
}
```

---

# Refresh Token

`POST /auth/refresh/`

Request:

```json
{
  "refresh": "REFRESH_TOKEN"
}
```

Response:

```json
{
  "access": "NEW_ACCESS_TOKEN"
}
```

---

# Logout

`POST /auth/logout/`

Authorization:

`Bearer ACCESS_TOKEN`

Request:

```json
{
  "refresh": "REFRESH_TOKEN"
}
```

Response:

```json
{
  "message": "Logout successful"
}
```

---

# Current User

`GET /users/me/`

Authorization:

`Bearer ACCESS_TOKEN`

Response:

```json
{
  "id": 1,
  "username": "user1",
  "email": "user@example.com",
  "avatar": null,
  "is_online": true,
  "last_seen": "2026-08-10T10:30:00Z"
}
```

---

# Update User

`PATCH /users/me/`

Authorization:

`Bearer ACCESS_TOKEN`

Request (Multipart form-data or JSON):

```json
{
  "username": "new_username",
  "avatar": "avatar_url"
}
```

---

# Search Users

`GET /users/?search=user`

Authorization:

`Bearer ACCESS_TOKEN`

Response:

```json
{
  "results": [
    {
      "id": 2,
      "username": "user2",
      "avatar": null,
      "is_online": true
    }
  ]
}
```

---

# Conversations

## List

`GET /conversations/`

Authorization:

`Bearer ACCESS_TOKEN`

Response:

```json
{
  "results": [
    {
      "id": 1,
      "type": "private",
      "name": null,
      "created_by": 1,
      "members": [],
      "last_message": null,
      "updated_at": "2026-08-10T10:30:00Z"
    }
  ]
}
```

---

# Create Conversation

`POST /conversations/`

Authorization:

`Bearer ACCESS_TOKEN`

Private conversation request:

```json
{
  "type": "private",
  "member_ids": [2]
}
```

Group conversation request:

```json
{
  "type": "group",
  "name": "Project Team",
  "member_ids": [2, 3, 4]
}
```

Kurallar:

* Conversation oluşturan kullanıcı otomatik member ve admin olur.
* Group conversation maksimum 5 kullanıcı içerebilir.
* Private conversation yalnızca iki kullanıcı içerebilir.

---

# Conversation Detail

`GET /conversations/{id}/`

Authorization:

`Bearer ACCESS_TOKEN`

---

# Update Conversation

`PATCH /conversations/{id}/`

Authorization:

`Bearer ACCESS_TOKEN`

Sadece group admin kullanabilir.

Örneğin:

```json
{
  "name": "New Group Name"
}
```

---

# Delete Conversation

`DELETE /conversations/{id}/`

Authorization:

`Bearer ACCESS_TOKEN`

Sadece group admin kullanabilir.

---

# Conversation Members

`GET /conversations/{id}/members/`

Authorization:

`Bearer ACCESS_TOKEN`

---

# Add Member

`POST /conversations/{id}/members/`

Authorization:

`Bearer ACCESS_TOKEN`

Request:

```json
{
  "user_id": 5
}
```

Sadece group admin kullanabilir.

---

# Remove Member

`DELETE /conversations/{id}/members/{user_id}/`

Authorization:

`Bearer ACCESS_TOKEN`

Sadece group admin kullanabilir.

---

# Message History

`GET /conversations/{id}/messages/`

Authorization:

`Bearer ACCESS_TOKEN`

Query parameters:

`?page=1&page_size=30`

Mesajlar newest veya oldest sıralaması proje boyunca tek bir standartta kullanılmalıdır.

Önerilen:

created_at descending.

---

# Chat Screens

Chat List ve Chat Detail ekranları ayrı `/chats/` endpointleri kullanmayacaktır.
Bu ekranlar conversation endpointleri üzerinden beslenecektir:

* Chat List → `GET /conversations/`
* Chat Detail → `GET /conversations/{id}/`
* Chat Messages → `GET /conversations/{id}/messages/`
* New Chat → `POST /conversations/`

---

# Authentication Header

Authenticated REST requests:

`Authorization: Bearer ACCESS_TOKEN`

---

# HTTP Status Codes

200 → Success

201 → Created

204 → Deleted successfully

400 → Bad Request

401 → Unauthorized

403 → Forbidden

404 → Not Found

409 → Conflict

500 → Internal Server Error
