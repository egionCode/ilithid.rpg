/// Formats a past [DateTime] as a short relative label in Portuguese
/// ("agora", "há 2 min", "há 3 h", "há 5 dias"), used by the log feed
/// (Story 8.2) instead of a raw timestamp.
String formatRelativeTime(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(timestamp);

  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} dias';
}
