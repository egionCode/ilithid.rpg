import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

class NpcTemplate extends Equatable {
  final String id;
  final String creatorId;
  final String name;
  final int hpMax;
  final int ac;
  final String sourceSystem;
  final bool isPublic;
  final DateTime createdAt;

  const NpcTemplate({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.hpMax,
    required this.ac,
    this.sourceSystem = 'manual',
    this.isPublic = true,
    required this.createdAt,
  });

  /// Factory constructor to create an NpcTemplate from a database row.
  factory NpcTemplate.fromRow(models.Row row) {
    final data = row.data;
    return NpcTemplate(
      id: row.$id,
      creatorId: (data['creatorId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      hpMax: (data['hpMax'] as num?)?.toInt() ?? 0,
      ac: (data['ac'] as num?)?.toInt() ?? 10,
      sourceSystem: (data['sourceSystem'] as String?) ?? 'manual',
      isPublic: (data['isPublic'] as bool?) ?? true,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the NpcTemplate instance into a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'name': name,
      'hpMax': hpMax,
      'ac': ac,
      'sourceSystem': sourceSystem,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    creatorId,
    name,
    hpMax,
    ac,
    sourceSystem,
    isPublic,
    createdAt,
  ];
}
