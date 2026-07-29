import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/combat/domain/log_entry.dart';

void main() {
  group('LogEntryType.fromCode', () {
    test('maps each known code back to its enum value', () {
      expect(LogEntryType.fromCode('damage'), LogEntryType.damage);
      expect(LogEntryType.fromCode('heal'), LogEntryType.heal);
      expect(LogEntryType.fromCode('temp_hp'), LogEntryType.tempHp);
      expect(LogEntryType.fromCode('item_use'), LogEntryType.itemUse);
      expect(LogEntryType.fromCode('death'), LogEntryType.death);
      expect(LogEntryType.fromCode('custom'), LogEntryType.custom);
    });

    test('falls back to custom for unknown or null codes', () {
      expect(LogEntryType.fromCode('unknown'), LogEntryType.custom);
      expect(LogEntryType.fromCode(null), LogEntryType.custom);
    });
  });

  group('LogEntry.toMap/fromRow round-trip', () {
    test('code survives a round trip through toMap', () {
      final entry = LogEntry(
        id: 'log-1',
        sessionId: 'session-1',
        type: LogEntryType.death,
        message: 'Orc foi derrotado(a).',
        actorName: 'GM',
        timestamp: DateTime.parse('2026-01-01T00:00:00.000Z'),
      );

      final map = entry.toMap();
      expect(map['type'], 'death');
      expect(LogEntryType.fromCode(map['type'] as String), LogEntryType.death);
    });
  });
}
