import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

class Character extends Equatable {
  final String id;
  final String userId;
  final String name;
  final int hpCurrent;
  final int hpMax;
  final int hpTemp;
  final int ac;
  final String sourceSystem;
  final String? rawJson;
  final DateTime createdAt;

  const Character({
    required this.id,
    required this.userId,
    required this.name,
    required this.hpCurrent,
    required this.hpMax,
    this.hpTemp = 0,
    required this.ac,
    this.sourceSystem = 'manual',
    this.rawJson,
    required this.createdAt,
  });

  /// Factory constructor to create a Character from a database row.
  factory Character.fromRow(models.Row row) {
    final data = row.data;
    return Character(
      id: row.$id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      hpCurrent: (data['hpCurrent'] as num?)?.toInt() ?? 0,
      hpMax: (data['hpMax'] as num?)?.toInt() ?? 0,
      hpTemp: (data['hpTemp'] as num?)?.toInt() ?? 0,
      ac: (data['ac'] as num?)?.toInt() ?? 10,
      sourceSystem: (data['sourceSystem'] as String?) ?? 'manual',
      rawJson: data['rawJson'] as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Converts the Character instance into a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'hpCurrent': hpCurrent,
      'hpMax': hpMax,
      'hpTemp': hpTemp,
      'ac': ac,
      'sourceSystem': sourceSystem,
      'rawJson': rawJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    hpCurrent,
    hpMax,
    hpTemp,
    ac,
    sourceSystem,
    rawJson,
    createdAt,
  ];
}
