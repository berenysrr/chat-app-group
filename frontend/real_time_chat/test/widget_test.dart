import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/main.dart';
import 'package:real_time_chat/chat/models/chat_models.dart';
import 'package:real_time_chat/chat/services/mock_web_socket_service.dart';
import 'package:real_time_chat/chat/widgets/chat_widgets.dart';

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

  testWidgets('presence events update only their matching users', (
    tester,
  ) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('online-2')), findsNothing);
    expect(find.byKey(const ValueKey('online-3')), findsNothing);
    expect(find.byKey(const ValueKey('online-4')), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('online-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-2')), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('online-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-4')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('online-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-3')), findsNothing);
    expect(find.byKey(const ValueKey('online-4')), findsNothing);
  });

  testWidgets('unknown presence is ignored and detail shares list state', (
    tester,
  ) async {
    final socket = MockWebSocketService();
    await tester.pumpWidget(ChatApp(socketOverride: socket));
    await tester.pump(const Duration(milliseconds: 300));
    socket.emitPresence(userId: 999, username: 'Bilinmeyen', online: true);
    await tester.pump();
    expect(find.byKey(const ValueKey('online-2')), findsNothing);
    expect(find.byKey(const ValueKey('online-3')), findsNothing);
    expect(find.byKey(const ValueKey('online-4')), findsNothing);

    socket.setPeerOnline(true);
    await tester.pump();
    expect(find.byKey(const ValueKey('online-2')), findsOneWidget);
    await tester.tap(find.text('Ece'));
    await tester.pumpAndSettle();
    expect(find.text('çevrimiçi'), findsOneWidget);
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
          matching: find.text('Tamamdır, teşekkürler.'),
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

  testWidgets('fallback avatar color is stable per user and differs by id', (
    tester,
  ) async {
    Future<Color> avatarColor(ChatUser user) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UserAvatar(user: user)),
        ),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(ValueKey('avatar-${user.id}')),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      return (decoration.gradient! as LinearGradient).colors.last;
    }

    final firstEceColor = await avatarColor(
      const ChatUser(id: 2, username: 'Ece'),
    );
    final mertColor = await avatarColor(
      const ChatUser(id: 3, username: 'Mert'),
    );
    final rebuiltEceColor = await avatarColor(
      const ChatUser(id: 2, username: 'Ece'),
    );

    expect(firstEceColor, rebuiltEceColor);
    expect(firstEceColor, isNot(mertColor));
  });

  testWidgets('chat list does not overflow on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sohbetler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout shows an inline detail panel', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VerticalDivider), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conversation-3')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('conversation-3')), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app uses the centralized dark theme', (tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('App loads splash screen test', (WidgetTester tester) async {
    await tester.pumpWidget(const RealTimeChatApp());
    expect(find.text('Chat'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2300));
  });
}
