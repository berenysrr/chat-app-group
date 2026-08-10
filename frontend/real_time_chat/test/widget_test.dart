import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/main.dart';
import 'package:real_time_chat/chat/services/mock_web_socket_service.dart';

void main() {
  testWidgets('opening a chat clears its unread badge', (tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sohbetler'), findsOneWidget);
    expect(find.text('Ece'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-4')), findsOneWidget);
    await tester.tap(find.text('Mert'));
    await tester.pumpAndSettle();
    expect(find.text('Mesaj yaz…'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-4')), findsNothing);
    expect(find.text('Okunmamış (0)'), findsOneWidget);
  });

  testWidgets('search filters chats by name and last message', (tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('chat-search')), 'Mert');
    await tester.pump();
    // One match is the search field value, the other is the filtered chat row.
    expect(find.text('Mert'), findsNWidgets(2));
    expect(find.text('Ece'), findsNothing);

    await tester.enterText(find.byKey(const Key('chat-search')), 'Yarın');
    await tester.pump();
    expect(find.text('Deniz'), findsOneWidget);
    expect(find.text('Mert'), findsNothing);
  });

  testWidgets('unread filter uses live unread conversation count', (
    tester,
  ) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Okunmamış (1)'), findsOneWidget);
    await tester.tap(find.text('Okunmamış (1)'));
    await tester.pump();
    expect(find.text('Mert'), findsOneWidget);
    expect(find.text('Ece'), findsNothing);
  });

  testWidgets('Mert and Deniz conversations open with the selected contact', (
    tester,
  ) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Mert'));
    await tester.pumpAndSettle();
    expect(find.text('Mert'), findsOneWidget);
    expect(find.text('Mesaj yaz…'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Dün'), findsOneWidget);
    await tester.tap(find.text('Deniz'));
    await tester.pumpAndSettle();
    expect(find.text('Deniz'), findsOneWidget);
    expect(find.text('Mesaj yaz…'), findsOneWidget);
  });

  testWidgets('presence badge follows mock online and offline events', (
    tester,
  ) async {
    final socket = MockWebSocketService();
    await tester.pumpWidget(ChatApp(socketOverride: socket));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('online-2')), findsOneWidget);
    socket.setPeerOnline(false);
    await tester.pump();
    expect(find.byKey(const ValueKey('online-2')), findsNothing);
    await socket.disconnect();
    await tester.pump();
    expect(find.text('Bağlantı yok'), findsOneWidget);
  });

  testWidgets('new chat button opens the contact picker placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.chat_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sohbet'), findsOneWidget);
    expect(find.textContaining('Kişi seçme ekranı'), findsOneWidget);
  });

  testWidgets(
    'activity moves a chat up and typing temporarily replaces preview',
    (tester) async {
      await tester.pumpWidget(const ChatApp());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Mert'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Yeni mesaj');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('conversation-4')),
          matching: find.text('yazıyor…'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('status-4')), findsOneWidget);
      final mertTop = tester
          .getTopLeft(find.byKey(const ValueKey('conversation-4')))
          .dy;
      final eceTop = tester
          .getTopLeft(find.byKey(const ValueKey('conversation-3')))
          .dy;
      expect(mertTop, lessThan(eceTop));

      await tester.pump(const Duration(seconds: 2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('conversation-4')),
          matching: find.text('Mesajını aldım, teşekkürler!'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('conversation-4')),
          matching: find.text('yazıyor…'),
        ),
        findsNothing,
      );
    },
  );
}
