from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ConversationViewSet, 
    ConversationMembersView, 
    ConversationMessageHistoryView
)

router = DefaultRouter()
router.register(r'conversations', ConversationViewSet, basename='conversation')

urlpatterns = [
    path('', include(router.urls)),
    path('conversations/<int:conversation_id>/members/', ConversationMembersView.as_view(), name='conversation-members'),
    path('conversations/<int:conversation_id>/members/<int:user_id>/', ConversationMembersView.as_view(), name='conversation-member-detail'),
    path('conversations/<int:conversation_id>/messages/', ConversationMessageHistoryView.as_view(), name='conversation-messages'),
]
