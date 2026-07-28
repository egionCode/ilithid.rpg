import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/combat/domain/relative_time.dart';

void main() {
  final now = DateTime.parse('2026-01-01T12:00:00.000Z');

  group('formatRelativeTime', () {
    test('less than a minute ago is "agora"', () {
      final ts = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(ts, now: now), 'agora');
    });

    test('minutes ago', () {
      final ts = now.subtract(const Duration(minutes: 2));
      expect(formatRelativeTime(ts, now: now), 'há 2 min');
    });

    test('just under an hour is still in minutes', () {
      final ts = now.subtract(const Duration(minutes: 59));
      expect(formatRelativeTime(ts, now: now), 'há 59 min');
    });

    test('hours ago', () {
      final ts = now.subtract(const Duration(hours: 3));
      expect(formatRelativeTime(ts, now: now), 'há 3 h');
    });

    test('just under a day is still in hours', () {
      final ts = now.subtract(const Duration(hours: 23));
      expect(formatRelativeTime(ts, now: now), 'há 23 h');
    });

    test('days ago', () {
      final ts = now.subtract(const Duration(days: 5));
      expect(formatRelativeTime(ts, now: now), 'há 5 dias');
    });
  });
}
