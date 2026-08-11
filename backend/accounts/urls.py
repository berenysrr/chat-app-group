from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    LoginView,
    RegisterView,
    LogoutView,
    CurrentUserView,
    UserSearchView,
    PresenceHeartbeatView,
    PresenceOfflineView,
)

auth_urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='token_obtain_pair'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', LogoutView.as_view(), name='logout'),
]

user_urlpatterns = [
    path('me/', CurrentUserView.as_view(), name='current_user'),
    path('presence/heartbeat/', PresenceHeartbeatView.as_view(), name='presence_heartbeat'),
    path('presence/offline/', PresenceOfflineView.as_view(), name='presence_offline'),
    path('', UserSearchView.as_view(), name='user_search'),
]

urlpatterns = auth_urlpatterns + user_urlpatterns
