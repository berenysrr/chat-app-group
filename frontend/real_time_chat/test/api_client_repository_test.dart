import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:real_time_chat/auth/token_store.dart';
import 'package:real_time_chat/chat/services/chat_repository.dart';
import 'package:real_time_chat/network/api_client.dart';

void main() {
  test(
    'authenticated request uses normalized API URL and bearer token',
    () async {
      late http.Request captured;
      final client = AuthenticatedApiClient(
        baseUrl: 'http://localhost:8000/api',
        tokens: MemoryTokenStore(accessToken: 'access'),
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"results":[]}', 200);
        }),
      );

      await ChatRepository(client).searchUsers('ece deniz');

      expect(captured.url.path, '/api/users/');
      expect(captured.url.queryParameters['search'], 'ece deniz');
      expect(captured.headers['Authorization'], 'Bearer access');
    },
  );

  test('401 refreshes once, stores access token and retries request', () async {
    var protectedCalls = 0;
    var refreshCalls = 0;
    final tokens = MemoryTokenStore(
      accessToken: 'expired',
      refreshToken: 'refresh',
    );
    final client = AuthenticatedApiClient(
      baseUrl: 'http://localhost:8000/api/',
      tokens: tokens,
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/refresh/') {
          refreshCalls++;
          expect(jsonDecode(request.body), {'refresh': 'refresh'});
          return http.Response('{"access":"new-access"}', 200);
        }
        protectedCalls++;
        if (request.headers['Authorization'] == 'Bearer expired') {
          return http.Response('{"detail":"expired"}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response(
          '{"id":1,"username":"user1","email":"u@e.com",'
          '"avatar":null,"is_online":true,"last_seen":null}',
          200,
        );
      }),
    );

    final user = await ChatRepository(client).currentUser();

    expect(user.id, 1);
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
    expect(await tokens.readAccessToken(), 'new-access');
  });

  test('repository sends private conversation contract body', () async {
    late http.Request captured;
    final client = AuthenticatedApiClient(
      baseUrl: 'http://localhost:8000/api/',
      tokens: MemoryTokenStore(accessToken: 'access'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"id":7,"type":"private","name":null,"created_by":1,'
          '"members":[],"last_message":null,'
          '"updated_at":"2026-08-10T10:30:00Z"}',
          201,
        );
      }),
    );

    final conversation = await ChatRepository(
      client,
    ).createPrivateConversation(2);

    expect(captured.url.path, '/api/conversations/');
    expect(jsonDecode(captured.body), {
      'type': 'private',
      'member_ids': [2],
    });
    expect(conversation.id, 7);
  });

  test('history uses before_id and returns chronological messages', () async {
    late Uri captured;
    final client = AuthenticatedApiClient(
      baseUrl: 'http://localhost:8000/api/',
      tokens: MemoryTokenStore(accessToken: 'access'),
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(
          '{"results":['
          '{"id":2,"client_message_id":"b","conversation_id":3,'
          '"sender":{"id":2,"username":"B","avatar":null},'
          '"content":"ikinci","message_type":"text",'
          '"created_at":"2026-08-10T10:31:00Z"},'
          '{"id":1,"client_message_id":"a","conversation_id":3,'
          '"sender":{"id":1,"username":"A","avatar":null},'
          '"content":"ilk","message_type":"text",'
          '"created_at":"2026-08-10T10:30:00Z"}'
          '],"next":null}',
          200,
        );
      }),
    );

    final page = await ChatRepository(client).messages(3, beforeId: 15);

    expect(captured.path, '/api/conversations/3/messages/');
    expect(captured.queryParameters['before_id'], '15');
    expect(page.messages.map((item) => item.id), [1, 2]);
  });
}
