# API Contract - Authentication & User Management

All endpoints are prefixed with `/api/accounts/`.

## 1. Register User
- **Endpoint:** `POST /api/accounts/register/`
- **Authentication:** None (Public)
- **Request Body:**
  ```json
  {
    "username": "john_doe",
    "email": "john@example.com",
    "password": "strongpassword123"
  }
  ```
- **Response (201 Created):**
  ```json
  {
    "user": {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "avatar": null,
      "is_online": false,
      "last_seen": null,
      "created_at": "2026-08-10T12:00:00Z",
      "updated_at": "2026-08-10T12:00:00Z"
    },
    "refresh": "eyJhbGciOi...",
    "access": "eyJhbGciOi..."
  }
  ```

---

## 2. Login User (Obtain JWT Tokens)
- **Endpoint:** `POST /api/accounts/login/`
- **Authentication:** None (Public)
- **Request Body:**
  ```json
  {
    "username": "john_doe",
    "password": "strongpassword123"
  }
  ```
- **Response (200 OK):**
  ```json
  {
    "refresh": "eyJhbGciOi...",
    "access": "eyJhbGciOi..."
  }
  ```

---

## 3. Refresh JWT Token
- **Endpoint:** `POST /api/accounts/token/refresh/`
- **Authentication:** None (Public)
- **Request Body:**
  ```json
  {
    "refresh": "eyJhbGciOi..."
  }
  ```
- **Response (200 OK):**
  ```json
  {
    "access": "eyJhbGciOi...",
    "refresh": "eyJhbGciOi..." // If token rotation is enabled
  }
  ```

---

## 4. Logout User (Blacklist Token)
- **Endpoint:** `POST /api/accounts/logout/`
- **Authentication:** Required (Bearer Token)
- **Request Body:**
  ```json
  {
    "refresh": "eyJhbGciOi..."
  }
  ```
- **Response (200 OK):**
  ```json
  {
    "detail": "Successfully logged out."
  }
  ```

---

## 5. Get Current User Profile
- **Endpoint:** `GET /api/accounts/me/`
- **Authentication:** Required (Bearer Token)
- **Response (200 OK):**
  ```json
  {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "avatar": "http://localhost:8000/media/avatars/john_doe.png",
    "is_online": true,
    "last_seen": "2026-08-10T12:05:00Z",
    "created_at": "2026-08-10T12:00:00Z",
    "updated_at": "2026-08-10T12:05:00Z"
  }
  ```

---

## 6. Update Profile
- **Endpoint:** `PATCH /api/accounts/update/` (or `PUT`)
- **Authentication:** Required (Bearer Token)
- **Request Body (Multipart Form-Data for avatar upload, or JSON):**
  - `username` (optional)
  - `email` (optional)
  - `avatar` (optional, File/Image)
- **Response (200 OK):**
  ```json
  {
    "username": "john_updated",
    "email": "john_new@example.com",
    "avatar": "http://localhost:8000/media/avatars/new_john.png"
  }
  ```

---

## 7. Search Users
- **Endpoint:** `GET /api/accounts/search/?q=<query_string>`
- **Authentication:** Required (Bearer Token)
- **Response (200 OK):**
  ```json
  [
    {
      "id": 2,
      "username": "jane_doe",
      "email": "jane@example.com",
      "avatar": null,
      "is_online": false,
      "last_seen": "2026-08-10T11:00:00Z",
      "created_at": "2026-08-10T10:00:00Z",
      "updated_at": "2026-08-10T10:30:00Z"
    }
  ]
  ```
  *(Returns an empty list `[]` if query parameter `q` is empty or no match is found. Excludes the current authenticated user from results.)*
