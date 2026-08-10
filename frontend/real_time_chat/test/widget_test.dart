import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/main.dart';

void main() {
  testWidgets('opening a chat clears its unread badge', (tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sohbetler'), findsOneWidget);
    expect(find.text('Ece'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-3')), findsOneWidget);
    await tester.tap(find.text('Ece'));
    await tester.pumpAndSettle();
    expect(find.text('Mesaj yaz…'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-3')), findsNothing);
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
    expect(find.text('Ece'), findsOneWidget);
    expect(find.text('Mert'), findsNothing);
  });
}
