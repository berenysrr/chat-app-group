from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status
from chat.models import Conversation, ConversationMember, Message, MessageRead

User = get_user_model()

class ChatBackendTests(APITestCase):

    def setUp(self):
        # Test kullanıcıları oluştur
        self.user1 = User.objects.create_user(username='user1', email='user1@example.com', password='password123')
        self.user2 = User.objects.create_user(username='user2', email='user2@example.com', password='password123')
        self.user3 = User.objects.create_user(username='user3', email='user3@example.com', password='password123')

        self.client.force_authenticate(user=self.user1)

    def test_create_private_conversation(self):
        response = self.client.post('/api/conversations/', {
            'type': 'private',
            'target_user_id': self.user2.id
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['type'], 'private')
        self.assertEqual(len(response.data['members']), 2)

    def test_create_duplicate_private_conversation_returns_existing(self):
        # İlk private conversation
        res1 = self.client.post('/api/conversations/', {
            'type': 'private',
            'target_user_id': self.user2.id
        }, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Tekrar aynı kullanıcı ile private conversation açmaya çalış
        res2 = self.client.post('/api/conversations/', {
            'type': 'private',
            'target_user_id': self.user2.id
        }, format='json')
        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res1.data['id'], res2.data['id'])

    def test_create_group_conversation(self):
        response = self.client.post('/api/conversations/', {
            'type': 'group',
            'name': 'Dev Team',
            'member_ids': [self.user2.id, self.user3.id]
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['type'], 'group')
        self.assertEqual(response.data['name'], 'Dev Team')
        self.assertEqual(len(response.data['members']), 3)

    def test_group_max_10_members_validation(self):
        # 10 kişiden fazla üye eklemeyi dene
        users = [User.objects.create_user(username=f'u{i}', email=f'u{i}@example.com', password='pass') for i in range(11)]
        user_ids = [u.id for u in users]

        response = self.client.post('/api/conversations/', {
            'type': 'group',
            'name': 'Large Group',
            'member_ids': user_ids
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_non_member_cannot_access_conversation(self):
        conv = Conversation.objects.create(type='private', created_by=self.user2)
        ConversationMember.objects.create(conversation=conv, user=self.user2, role='admin')
        ConversationMember.objects.create(conversation=conv, user=self.user3, role='member')

        # user1 bu odanın üyesi değil - 404 Not Found veya 403 Forbidden döner
        response = self.client.get(f'/api/conversations/{conv.id}/')
        self.assertIn(response.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND])

    def test_message_history_api(self):
        conv = Conversation.objects.create(type='private', created_by=self.user1)
        ConversationMember.objects.create(conversation=conv, user=self.user1, role='admin')
        ConversationMember.objects.create(conversation=conv, user=self.user2, role='member')

        # Test mesajları
        for i in range(25):
            Message.objects.create(
                conversation=conv,
                sender=self.user1,
                content=f'Message {i}'
            )

        response = self.client.get(f'/api/conversations/{conv.id}/messages/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Pagination sayfa başı 20 mesaj döndürür
        self.assertEqual(len(response.data['results']), 20)
        self.assertEqual(response.data['count'], 25)
