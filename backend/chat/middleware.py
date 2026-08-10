from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from accounts.models import User


@database_sync_to_async
def get_user_from_token(token_string):
    """
    Token string'ini alır, doğrulamazsa AnonymousUser döndürür.
    Doğrularsa veritabanından ilgili User objesini bulup getirir.
    """
    try:
        # Token'ı çöz ve içindeki user_id'yi al
        access_token = AccessToken(token_string)
        user_id = access_token['user_id']
        return User.objects.get(id=user_id)
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware:
    """
    WebSocket bağlantılarında URL'deki ?token=... parametresini okuyan
    ve kullanıcıyı doğrulayan kapı görevlisi (Middleware).
    """

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        # URL parametrelerini ayrıştır (örneğin: ?token=abc123xyz)
        query_string = scope.get("query_string", b"").decode("utf-8")
        query_params = parse_qs(query_string)

        token = query_params.get("token", [None])[0]

        if token:
            # Token varsa kullanıcıyı doğrula
            scope["user"] = await get_user_from_token(token)
        else:
            # Token yoksa kullanıcıyı anonim yap
            scope["user"] = AnonymousUser()

        return await self.inner(scope, receive, send)