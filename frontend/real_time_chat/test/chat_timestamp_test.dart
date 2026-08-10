import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_chat/chat/utils/chat_timestamp.dart';

void main() {
  final now = DateTime(2026, 8, 10, 15, 30);

  test('formats today as time', () {
    expect(
      formatChatTimestamp(DateTime(2026, 8, 10, 9, 5), relativeTo: now),
      '09:05',
    );
  });

  test('formats yesterday as a readable label', () {
    expect(
      formatChatTimestamp(DateTime(2026, 8, 9, 22), relativeTo: now),
      'Dün',
    );
  });

  test('formats older dates with a full date', () {
    expect(
      formatChatTimestamp(DateTime(2026, 7, 2), relativeTo: now),
      '02.07.2026',
    );
  });
}
