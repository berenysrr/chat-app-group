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
            'member_ids': [self.user2.id]
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['type'], 'private')
        self.assertEqual(len(response.data['members']), 2)

    def test_conversation_list_uses_contract_results_wrapper(self):
        conversation = Conversation.objects.create(type='private', created_by=self.user1)
        ConversationMember.objects.create(conversation=conversation, user=self.user1, role='admin')
        ConversationMember.objects.create(conversation=conversation, user=self.user2, role='member')

        response = self.client.get('/api/conversations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertEqual(response.data['results'][0]['id'], conversation.id)

    def test_create_duplicate_private_conversation_returns_existing(self):
        # İlk private conversation
        res1 = self.client.post('/api/conversations/', {
            'type': 'private',
            'member_ids': [self.user2.id]
        }, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Tekrar aynı kullanıcı ile private conversation açmaya çalış
        res2 = self.client.post('/api/conversations/', {
            'type': 'private',
            'member_ids': [self.user2.id]
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

    def test_group_max_5_members_validation(self):
        users = [User.objects.create_user(username=f'u{i}', email=f'u{i}@example.com', password='pass') for i in range(5)]
        user_ids = [u.id for u in users]

        response = self.client.post('/api/conversations/', {
            'type': 'group',
            'name': 'Large Group',
            'member_ids': user_ids
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_non_admin_cannot_rename_group(self):
        conversation = Conversation.objects.create(type='group', name='Team', created_by=self.user1)
        ConversationMember.objects.create(conversation=conversation, user=self.user1, role='admin')
        ConversationMember.objects.create(conversation=conversation, user=self.user2, role='member')

        self.client.force_authenticate(user=self.user2)
        response = self.client.patch(
            f'/api/conversations/{conversation.id}/',
            {'name': 'Renamed'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

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

    def test_unread_count_uses_distinct_per_message(self):
        conversation = Conversation.objects.create(type='group', created_by=self.user1)
        ConversationMember.objects.create(conversation=conversation, user=self.user1, role='admin')
        ConversationMember.objects.create(conversation=conversation, user=self.user2, role='member')
        ConversationMember.objects.create(conversation=conversation, user=self.user3, role='member')

        message = Message.objects.create(
            conversation=conversation,
            sender=self.user2,
            content='hello group',
        )
        MessageRead.objects.create(message=message, user=self.user2)
        MessageRead.objects.create(message=message, user=self.user3)

        response = self.client.get('/api/conversations/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['results'][0]['unread_count'], 1)

    def test_mark_read_endpoint_marks_all_unread_messages(self):
        conversation = Conversation.objects.create(type='private', created_by=self.user2)
        ConversationMember.objects.create(conversation=conversation, user=self.user1, role='member')
        ConversationMember.objects.create(conversation=conversation, user=self.user2, role='admin')

        first = Message.objects.create(
            conversation=conversation,
            sender=self.user2,
            content='one',
        )
        second = Message.objects.create(
            conversation=conversation,
            sender=self.user2,
            content='two',
        )

        before = self.client.get('/api/conversations/')
        self.assertEqual(before.status_code, status.HTTP_200_OK)
        self.assertEqual(before.data['results'][0]['unread_count'], 2)

        response = self.client.post(f'/api/conversations/{conversation.id}/read/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['marked_count'], 2)
        self.assertTrue(
            MessageRead.objects.filter(message=first, user=self.user1).exists()
        )
        self.assertTrue(
            MessageRead.objects.filter(message=second, user=self.user1).exists()
        )

        after = self.client.get('/api/conversations/')
        self.assertEqual(after.status_code, status.HTTP_200_OK)
        self.assertEqual(after.data['results'][0]['unread_count'], 0)
