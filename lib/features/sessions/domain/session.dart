import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final String campaignId;
  final String status; // 'active' or 'finished'
  final DateTime startedAt;
  final DateTime? endedAt;

  const Session({
    required this.id,
    required this.campaignId,
    required this.status,
    required this.startedAt,
    this.endedAt,
  });

  /// Factory constructor to create a Session from a database row.
  factory Session.fromRow(models.Row row) {
    final data = row.data;
    return Session(
      id: row.$id,
      campaignId: (data['campaignId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'active',
      startedAt: data['startedAt'] != null
          ? DateTime.parse(data['startedAt'] as String)
          : DateTime.now(),
      endedAt: data['endedAt'] != null
          ? DateTime.parse(data['endedAt'] as String)
          : null,
    );
  }

  /// Converts the Session instance into a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'status': status,
      'startedAt': startedAt.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, campaignId, status, startedAt, endedAt];
}
