import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

class CampaignMember extends Equatable {
  final String id;
  final String campaignId;
  final String userId;
  final String? activeCharacterId;
  final String role;
  final DateTime joinedAt;

  const CampaignMember({
    required this.id,
    required this.campaignId,
    required this.userId,
    this.activeCharacterId,
    required this.role,
    required this.joinedAt,
  });

  /// Factory constructor to create a CampaignMember from a database row.
  factory CampaignMember.fromRow(models.Row row) {
    final data = row.data;
    return CampaignMember(
      id: row.$id,
      campaignId: (data['campaignId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      activeCharacterId: data['activeCharacterId'] as String?,
      role: (data['role'] as String?) ?? 'player',
      joinedAt: data['joinedAt'] != null
          ? DateTime.parse(data['joinedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the CampaignMember instance into a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'userId': userId,
      'activeCharacterId': activeCharacterId,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    campaignId,
    userId,
    activeCharacterId,
    role,
    joinedAt,
  ];
}
