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

String formatLastSeen(DateTime value, {DateTime? relativeTo}) {
  final local = value.isUtc ? value.toLocal() : value;
  final now = relativeTo ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final valueDay = DateTime(local.year, local.month, local.day);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (valueDay == today) return 'son görülme bugün $time';
  if (valueDay == today.subtract(const Duration(days: 1))) {
    return 'son görülme dün $time';
  }
  final date =
      '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  return 'son görülme $date $time';
}
