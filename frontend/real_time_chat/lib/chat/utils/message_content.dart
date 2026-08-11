class GifMessageContent {
  const GifMessageContent({required this.label, required this.url});

  final String label;
  final String url;
}

String encodeGifMessage(GifMessageContent gif) =>
    '__gif__|${gif.label}|${gif.url}';

GifMessageContent? parseGifMessage(String content) {
  if (!content.startsWith('__gif__|')) return null;
  final parts = content.split('|');
  if (parts.length < 3) return null;
  return GifMessageContent(label: parts[1], url: parts.sublist(2).join('|'));
}

bool isAudioMessage({required String messageType, required String content}) {
  final normalized = messageType.trim().toLowerCase();
  return normalized == 'audio' || content.trimLeft().startsWith('data:audio/');
}

String previewTextForMessage({
  required String content,
  String messageType = 'text',
}) {
  if (isAudioMessage(messageType: messageType, content: content)) {
    return '🎤 Sesli mesaj';
  }
  final gif = parseGifMessage(content);
  if (gif != null) return 'GIF · ${gif.label}';
  final normalized = content.trim();
  return normalized.isEmpty ? 'Henüz mesaj yok' : normalized;
}
