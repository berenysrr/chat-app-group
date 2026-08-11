String? resolveAvatarUrl(String? raw, {required String baseUrl}) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;

  final base = Uri.parse(baseUrl);
  final normalizedPath = value.startsWith('/') ? value : '/$value';
  return base.replace(path: normalizedPath, query: null, fragment: null).toString();
}
