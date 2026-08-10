# Database Contract

## 1. User

Django'nun custom User modeli kullanılacaktır.

Alanlar:

* id
* username
* email
* password
* avatar
* is_online
* last_seen
* created_at
* updated_at

Kurallar:

* username unique olmalıdır.
* email unique olmalıdır.
* password plain text tutulmayacaktır.
* Django password hashing kullanılacaktır.
* created_at otomatik oluşturulacaktır.
* updated_at otomatik güncellenecektir.

---

# 2. Conversation

Alanlar:

* id
* type
* name
* created_by
* created_at
* updated_at

type değerleri:

* private
* group

Kurallar:

* private conversation iki kullanıcı arasında olabilir.
* group conversation birden fazla kullanıcı içerebilir.
* group conversation maksimum 5 kullanıcı içerecektir.
* created_by conversation'ı oluşturan kullanıcıdır.

---

# 3. ConversationMember

Alanlar:

* id
* conversation
* user
* role
* joined_at

role değerleri:

* admin
* member

Kurallar:

* Aynı kullanıcı aynı conversation'a iki kez eklenemez.
* Conversation oluşturulduğunda oluşturan kullanıcı otomatik olarak admin olur.
* Kullanıcı yalnızca üyesi olduğu conversation'a erişebilir.

---

# 4. Message

Alanlar:

* id
* conversation
* sender
* content
* message_type
* created_at
* updated_at
* is_deleted

message_type:

* text

İlk versiyonda yalnızca text mesaj desteklenecektir.

Kurallar:

* Boş mesaj gönderilemez.
* Mesaj yalnızca conversation üyesi tarafından gönderilebilir.
* Mesaj sender bilgisine sahip olmalıdır.
* Mesaj conversation'a bağlı olmalıdır.

---

# 5. MessageRead

Alanlar:

* id
* message
* user
* read_at

Kurallar:

* Bir kullanıcı aynı mesajı birden fazla kez read olarak oluşturmamalıdır.
* Kullanıcı mesajı gördüğünde read bilgisi oluşturulmalıdır.

---

# Relationships

User
↓
ConversationMember
↓
Conversation
↓
Message
↓
MessageRead

User → Message

Bir kullanıcı birden fazla mesaj gönderebilir.

User → ConversationMember

Bir kullanıcı birden fazla conversation'ın üyesi olabilir.

Conversation → Message

Bir conversation birden fazla mesaj içerebilir.

Conversation → ConversationMember

Bir conversation birden fazla kullanıcı içerebilir.
