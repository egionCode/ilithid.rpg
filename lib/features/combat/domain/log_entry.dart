import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

/// Combat log types recorded automatically by HP actions (Story 7.2/7.3),
/// consumed later by the visual feed (Epic 8).
enum LogEntryType { damage, heal, tempHp }

class LogEntry extends Equatable {
  final String id;
  final String sessionId;
  final LogEntryType type;
  final String message;
  final String actorName;
  final DateTime timestamp;

  const LogEntry({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.message,
    required this.actorName,
    required this.timestamp,
  });

  factory LogEntry.fromRow(models.Row row) {
    final data = row.data;
    return LogEntry(
      id: row.$id,
      sessionId: (data['sessionId'] as String?) ?? '',
      type: LogEntryType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => LogEntryType.damage,
      ),
      message: (data['message'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the LogEntry instance into a Map for database storage.
  ///
  /// Field names/types match the `logs` table schema provisioned in
  /// Appwrite (sessionId, type, message, actorName, timestamp - all
  /// required strings), not just the shape this feature happens to need.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'type': type.name,
      'message': message,
      'actorName': actorName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    type,
    message,
    actorName,
    timestamp,
  ];
}
