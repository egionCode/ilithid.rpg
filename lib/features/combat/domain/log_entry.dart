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
  final DateTime createdAt;

  const LogEntry({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.message,
    required this.createdAt,
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
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'type': type.name,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, sessionId, type, message, createdAt];
}
