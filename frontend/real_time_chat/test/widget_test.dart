import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/main.dart';

void main() {
  testWidgets('App loads splash screen test', (WidgetTester tester) async {
    await tester.pumpWidget(const RealTimeChatApp());
    expect(find.text('RealTime Chat'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
