import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/models/user_model.dart';
import 'package:real_time_chat/screens/chat_detail_screen.dart';

void main() {
  test('sender label is only enabled for incoming group messages', () {
    expect(
      shouldShowGroupSenderName(
        conversationType: 'group',
        isCurrentUser: false,
      ),
      isTrue,
    );
    expect(
      shouldShowGroupSenderName(
        conversationType: 'private',
        isCurrentUser: false,
      ),
      isFalse,
    );
    expect(
      shouldShowGroupSenderName(conversationType: 'group', isCurrentUser: true),
      isFalse,
    );
  });

  testWidgets('group sender label prefers username', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupMessageSenderName(
            sender: UserModel(
              id: 2,
              username: 'Ahmet Yılmaz',
              email: 'ahmet@example.com',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('ahmet@example.com'), findsNothing);
  });

  testWidgets('group sender label falls back to email', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupMessageSenderName(
            sender: UserModel(id: 2, username: ' ', email: 'ayse@example.com'),
          ),
        ),
      ),
    );

    expect(find.text('ayse@example.com'), findsOneWidget);
    final text = tester.widget<Text>(find.text('ayse@example.com'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
