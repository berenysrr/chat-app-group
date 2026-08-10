import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/main.dart';

void main() {
  testWidgets('chat list opens chat detail', (tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sohbetler'), findsOneWidget);
    expect(find.text('Ece'), findsOneWidget);
    await tester.tap(find.text('Ece'));
    await tester.pumpAndSettle();
    expect(find.text('Mesaj yaz…'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
  });
}
