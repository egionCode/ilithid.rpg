import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

class Campaign extends Equatable {
  final String id;
  final String hexId;
  final String name;
  final String gmUserId;
  final String status;
  final DateTime createdAt;

  const Campaign({
    required this.id,
    required this.hexId,
    required this.name,
    required this.gmUserId,
    required this.status,
    required this.createdAt,
  });

  /// Factory constructor to create a Campaign from a database row.
  factory Campaign.fromRow(models.Row row) {
    final data = row.data;
    return Campaign(
      id: row.$id,
      hexId: (data['hexId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      gmUserId: (data['gmUserId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'active',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the Campaign instance into a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'hexId': hexId,
      'name': name,
      'gmUserId': gmUserId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, hexId, name, gmUserId, status, createdAt];
}
