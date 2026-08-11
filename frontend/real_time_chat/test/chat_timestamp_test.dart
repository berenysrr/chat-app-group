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

  test('last seen bugün dün ve eski tarihleri saat ile biçimlendirir', () {
    final now = DateTime(2026, 8, 10, 15, 30);
    expect(
      formatLastSeen(DateTime(2026, 8, 10, 14, 9), relativeTo: now),
      'son görülme bugün 14:09',
    );
    expect(
      formatLastSeen(DateTime(2026, 8, 9, 22, 31), relativeTo: now),
      'son görülme dün 22:31',
    );
    expect(
      formatLastSeen(DateTime(2026, 8, 7, 18, 42), relativeTo: now),
      'son görülme 07.08.2026 18:42',
    );
  });
}
