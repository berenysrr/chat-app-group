String formatChatTimestamp(DateTime value, {DateTime? relativeTo}) {
  final now = relativeTo ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(value.year, value.month, value.day);
  if (messageDay == today) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  if (messageDay == today.subtract(const Duration(days: 1))) {
    return 'Dün';
  }
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
