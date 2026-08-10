from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    # ws://localhost:8000/ws/chat/{conversation_id}/ adresini ChatConsumer'a bağlar
    re_path(r"^ws/chat/(?P<conversation_id>\d+)/$", consumers.ChatConsumer.as_asgi()),
]