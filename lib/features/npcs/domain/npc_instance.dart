import 'package:appwrite/models.dart' as models;
import 'package:equatable/equatable.dart';

class NpcInstance extends Equatable {
  final String id;
  final String sessionId;
  final String? templateId;
  final String name;
  final int hpCurrent;
  final int hpMax;
  final int hpTemp;
  final int ac;

  const NpcInstance({
    required this.id,
    required this.sessionId,
    this.templateId,
    required this.name,
    required this.hpCurrent,
    required this.hpMax,
    this.hpTemp = 0,
    required this.ac,
  });

  /// Factory constructor to create an NpcInstance from a database row.
  factory NpcInstance.fromRow(models.Row row) {
    final data = row.data;
    return NpcInstance(
      id: row.$id,
      sessionId: (data['sessionId'] as String?) ?? '',
      templateId: data['templateId'] as String?,
      name: (data['name'] as String?) ?? '',
      hpCurrent: (data['hpCurrent'] as num?)?.toInt() ?? 0,
      hpMax: (data['hpMax'] as num?)?.toInt() ?? 0,
      hpTemp: (data['hpTemp'] as num?)?.toInt() ?? 0,
      ac: (data['ac'] as num?)?.toInt() ?? 10,
    );
  }

  /// Converts the NpcInstance instance into a Map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      if (templateId != null) 'templateId': templateId,
      'name': name,
      'hpCurrent': hpCurrent,
      'hpMax': hpMax,
      'hpTemp': hpTemp,
      'ac': ac,
    };
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    templateId,
    name,
    hpCurrent,
    hpMax,
    hpTemp,
    ac,
  ];
}
