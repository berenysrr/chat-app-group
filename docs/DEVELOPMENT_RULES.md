# Development Rules

## Git

main branch'e doğrudan push yapılmayacaktır.

Her geliştirici kendi branch'inde çalışacaktır.

Branch formatı:

feature/auth-backend
feature/chat-backend
feature/websocket
feature/flutter-auth
feature/flutter-chat

Commit mesajları açıklayıcı olmalıdır.

Örnek:

feat: add JWT authentication

feat: add conversation models

feat: implement websocket consumer

feat: add flutter login screen

fix: handle websocket reconnect

---

# Shared Contracts

API, database ve WebSocket contractları değiştirilmeden önce ekip ile konuşulmalıdır.

Bir geliştirici contract değiştirmek isterse:

1. Değişiklik açıklanır.
2. Frontend ve backend etkisi değerlendirilir.
3. docs dosyaları güncellenir.
4. Ekip bilgilendirilir.
5. Kod değişikliği yapılır.

---

# Backend

Backend:

Django
Django REST Framework
Django Channels
Redis
PostgreSQL
JWT

kullanacaktır.

---

# Frontend

Frontend:

Flutter
Dio
WebSocket
flutter_secure_storage

kullanacaktır.

---

# Real-time

Polling kullanılmayacaktır.

Gerçek zamanlı mesajlaşma WebSocket üzerinden yapılacaktır.

---

# Security

Secret bilgiler GitHub'a gönderilmeyecektir.

.env kullanılmalıdır.

Örnek:

.env.example

dosyası repository'de tutulabilir.

---

# Environment Variables

Backend:

SECRET_KEY=
DEBUG=
DATABASE_URL=
REDIS_URL=
JWT_SECRET_KEY=

Gerçek değerler .env içerisinde olacaktır.

.env GitHub'a gönderilmeyecektir.

---

# Code Quality

Kod tekrarından kaçınılmalıdır.

Business logic mümkün olduğunca service katmanında tutulmalıdır.

WebSocket consumer gereksiz business logic içermemelidir.

Frontend'de API ve WebSocket işlemleri UI widgetlarının içine yazılmamalıdır.

---
