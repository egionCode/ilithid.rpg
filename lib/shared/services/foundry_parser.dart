import 'dart:convert';

/// Whether a parsed Foundry actor is a player character or an NPC/monster,
/// derived from the Foundry `type` field.
enum FoundryEntityType { pc, npc }

/// Thrown when the input isn't valid JSON or isn't shaped like a Foundry
/// actor export, so callers can show a friendly error (Story 10.2/10.3).
class FoundryParseException implements Exception {
  final String message;
  const FoundryParseException(this.message);

  @override
  String toString() => message;
}

/// Result of parsing a Foundry VTT (D&D 5e system) actor JSON export.
class FoundryParseResult {
  final FoundryEntityType entityType;
  final String name;
  final int hpCurrent;
  final int hpMax;
  final int ac;

  /// Top-level fields present in the source JSON that this parser doesn't
  /// currently read, kept so future support can be prioritized (Story 10.1).
  final List<String> unrecognizedFields;

  const FoundryParseResult({
    required this.entityType,
    required this.name,
    required this.hpCurrent,
    required this.hpMax,
    required this.ac,
    required this.unrecognizedFields,
  });
}

/// Parses a Foundry VTT D&D 5e actor export into the fields ilithid needs
/// (Story 10.1). Only reads `name`, `type`, and
/// `system.attributes.{hp,ac}` - everything else is reported via
/// [FoundryParseResult.unrecognizedFields] instead of being dropped silently.
class FoundryParser {
  const FoundryParser._();

  static const _knownTopLevelKeys = {'name', 'type', 'system', '_id', 'img'};

  static FoundryParseResult parse(String jsonString) {
    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FoundryParseException(
          'O arquivo não parece ser uma ficha do Foundry (JSON raiz não é um objeto).',
        );
      }
      data = decoded;
    } on FoundryParseException {
      rethrow;
    } catch (_) {
      throw const FoundryParseException('O arquivo não é um JSON válido.');
    }

    final name = (data['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const FoundryParseException(
        'Campo "name" ausente ou vazio no arquivo.',
      );
    }

    final rawType = data['type'] as String?;
    final entityType = rawType == 'npc'
        ? FoundryEntityType.npc
        : FoundryEntityType.pc;

    final system = data['system'];
    final attributes = system is Map ? system['attributes'] : null;
    final hp = attributes is Map ? attributes['hp'] : null;
    final ac = attributes is Map ? attributes['ac'] : null;

    final hpCurrent = _toInt(hp is Map ? hp['value'] : null, defaultValue: 0);
    final hpMax = _toInt(hp is Map ? hp['max'] : null, defaultValue: 1);
    final acValue = _toInt(ac is Map ? ac['value'] : null, defaultValue: 10);

    final unrecognizedFields = data.keys
        .where((key) => !_knownTopLevelKeys.contains(key))
        .toList();

    return FoundryParseResult(
      entityType: entityType,
      name: name,
      hpCurrent: hpCurrent,
      hpMax: hpMax,
      ac: acValue,
      unrecognizedFields: unrecognizedFields,
    );
  }

  /// Foundry sometimes stores numeric attributes as strings; tryParse with a
  /// default keeps a single malformed field from failing the whole import.
  static int _toInt(dynamic value, {required int defaultValue}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}
