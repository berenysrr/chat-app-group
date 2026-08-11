import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/models/chat_models.dart';
import 'package:real_time_chat/chat/widgets/chat_widgets.dart';
import 'package:real_time_chat/models/conversation_model.dart';
import 'package:real_time_chat/models/user_model.dart';
import 'package:real_time_chat/theme/app_colors.dart';

Map<String, dynamic> messageJson({int readCount = 0}) => {
  'id': 15,
  'client_message_id': 'client-15',
  'conversation_id': 3,
  'sender': {'id': 1, 'username': 'Beren'},
  'content': 'Merhaba',
  'message_type': 'text',
  'created_at': '2026-08-10T10:30:00Z',
  'read_count': readCount,
};

void main() {
  test('REST read_count last message statusunu read olarak ayrıştırır', () {
    expect(
      ChatMessage.fromJson(messageJson(readCount: 1)).status,
      MessageStatus.read,
    );
    expect(ChatMessage.fromJson(messageJson()).status, MessageStatus.delivered);
  });

  test('message status eski event ile geriye dönmez', () {
    expect(
      latestMessageStatus(MessageStatus.read, MessageStatus.delivered),
      MessageStatus.read,
    );
    expect(
      latestMessageStatus(MessageStatus.sent, MessageStatus.delivered),
      MessageStatus.delivered,
    );
  });

  test(
    'read receipt yalnızca benim eşleşen last message kaydımı günceller',
    () {
      final mine = UserModel(id: 1, username: 'Ben', email: 'ben@example.com');
      final conversation = ConversationModel(
        id: 3,
        type: 'private',
        members: const [],
        lastMessage: LastMessageModel(id: 15, content: 'Merhaba', sender: mine),
      );

      final updated = applyReadReceiptToConversation(
        conversation,
        messageId: 15,
        currentUserId: 1,
      );
      expect(updated.lastMessage?.readCount, 1);
      expect(
        applyReadReceiptToConversation(
          conversation,
          messageId: 99,
          currentUserId: 1,
        ),
        same(conversation),
      );
      expect(
        applyReadReceiptToConversation(
          conversation,
          messageId: 15,
          currentUserId: 2,
        ),
        same(conversation),
      );
    },
  );

  testWidgets(
    'ortak status ikonu sent delivered ve read durumlarını gösterir',
    (tester) async {
      Future<Icon> render(MessageStatus status) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MessageStatusIcon(status: status)),
          ),
        );
        return tester.widget<Icon>(find.byType(Icon));
      }

      final sent = await render(MessageStatus.sent);
      expect(sent.icon, Icons.check_rounded);
      expect(sent.color, AppColors.textSecondary);

      final delivered = await render(MessageStatus.delivered);
      expect(delivered.icon, Icons.done_all_rounded);
      expect(delivered.color, AppColors.textSecondary);

      final read = await render(MessageStatus.read);
      expect(read.icon, Icons.done_all_rounded);
      expect(read.color, AppColors.accentBlue);
    },
  );
}
