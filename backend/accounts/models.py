from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from datetime import timedelta

PRESENCE_TTL_SECONDS = 15

class User(AbstractUser):
    email = models.EmailField(unique=True)
    avatar = models.ImageField(upload_to='avatars/', null=True, blank=True)
    is_online = models.BooleanField(default=False)
    last_seen = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Email is unique, let's keep email in REQUIRED_FIELDS
    REQUIRED_FIELDS = ['email']

    def is_effectively_online(self):
        if not self.is_online or self.last_seen is None:
            return False
        return self.last_seen >= timezone.now() - timedelta(seconds=PRESENCE_TTL_SECONDS)

    def __str__(self):
        return self.username
