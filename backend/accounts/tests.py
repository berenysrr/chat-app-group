from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.contrib.auth import get_user_model

User = get_user_model()

class AccountsAPITests(APITestCase):

    def setUp(self):
        self.register_url = reverse('register')
        self.login_url = reverse('token_obtain_pair')
        self.me_url = reverse('current_user')
        self.update_url = reverse('user_update')
        self.search_url = reverse('user_search')
        self.logout_url = reverse('logout')

        self.user_data = {
            'username': 'testuser',
            'email': 'testuser@example.com',
            'password': 'testpassword123'
        }
        self.user = User.objects.create_user(
            username='existinguser',
            email='existing@example.com',
            password='existingpassword123'
        )

    def test_user_registration(self):
        response = self.client.post(self.register_url, self.user_data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['user']['username'], 'testuser')
        self.assertEqual(response.data['user']['email'], 'testuser@example.com')

    def test_user_registration_duplicate_email(self):
        duplicate_data = {
            'username': 'anotheruser',
            'email': 'existing@example.com',
            'password': 'password123'
        }
        response = self.client.post(self.register_url, duplicate_data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_user_login(self):
        response = self.client.post(self.login_url, {
            'username': 'existinguser',
            'password': 'existingpassword123'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_get_current_user_unauthenticated(self):
        response = self.client.get(self.me_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_get_current_user_authenticated(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get(self.me_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], self.user.username)
        self.assertEqual(response.data['email'], self.user.email)

    def test_user_profile_update(self):
        self.client.force_authenticate(user=self.user)
        update_data = {
            'username': 'updatedusername',
            'email': 'updated@example.com'
        }
        response = self.client.patch(self.update_url, update_data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'updatedusername')
        self.assertEqual(response.data['email'], 'updated@example.com')

    def test_user_search(self):
        self.client.force_authenticate(user=self.user)
        
        # Create another user to search for
        User.objects.create_user(
            username='searchtarget',
            email='target@example.com',
            password='password123'
        )

        response = self.client.get(f"{self.search_url}?q=search")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['username'], 'searchtarget')

    def test_logout_blacklist(self):
        # Obtain tokens
        response = self.client.post(self.login_url, {
            'username': 'existinguser',
            'password': 'existingpassword123'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        refresh_token = response.data['refresh']
        access_token = response.data['access']

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        logout_response = self.client.post(self.logout_url, {'refresh': refresh_token})
        self.assertEqual(logout_response.status_code, status.HTTP_200_OK)
        self.assertEqual(logout_response.data['detail'], 'Successfully logged out.')
