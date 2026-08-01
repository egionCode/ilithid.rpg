import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/shared/services/foundry_parser.dart';

String _actorJson({
  String name = 'Aragorn',
  String type = 'character',
  int hpValue = 45,
  int hpMax = 50,
  int acValue = 16,
  Map<String, dynamic>? extraTopLevel,
}) {
  return jsonEncode({
    'name': name,
    'type': type,
    'system': {
      'attributes': {
        'hp': {'value': hpValue, 'max': hpMax},
        'ac': {'value': acValue},
      },
    },
    ...?extraTopLevel,
  });
}

void main() {
  group('FoundryParser.parse', () {
    test('extracts name, hp and ac for a PC', () {
      final result = FoundryParser.parse(_actorJson());

      expect(result.entityType, FoundryEntityType.pc);
      expect(result.name, 'Aragorn');
      expect(result.hpCurrent, 45);
      expect(result.hpMax, 50);
      expect(result.ac, 16);
    });

    test('detects type == npc as an NPC', () {
      final result = FoundryParser.parse(_actorJson(type: 'npc', name: 'Orc'));

      expect(result.entityType, FoundryEntityType.npc);
      expect(result.name, 'Orc');
    });

    test('any non-npc type is treated as a PC', () {
      final result = FoundryParser.parse(_actorJson(type: 'vehicle'));
      expect(result.entityType, FoundryEntityType.pc);
    });

    test('throws a friendly error for invalid JSON', () {
      expect(
        () => FoundryParser.parse('{not valid json'),
        throwsA(
          isA<FoundryParseException>().having(
            (e) => e.message,
            'message',
            contains('JSON válido'),
          ),
        ),
      );
    });

    test('throws a friendly error when the JSON root is not an object', () {
      expect(
        () => FoundryParser.parse(jsonEncode([1, 2, 3])),
        throwsA(isA<FoundryParseException>()),
      );
    });

    test('throws a friendly error when name is missing', () {
      final json = jsonEncode({'type': 'character', 'system': {}});
      expect(
        () => FoundryParser.parse(json),
        throwsA(
          isA<FoundryParseException>().having(
            (e) => e.message,
            'message',
            contains('name'),
          ),
        ),
      );
    });

    test('defaults missing hp/ac fields instead of failing', () {
      final json = jsonEncode({'name': 'Mystery Blob', 'type': 'npc'});
      final result = FoundryParser.parse(json);

      expect(result.hpCurrent, 0);
      expect(result.hpMax, 1);
      expect(result.ac, 10);
    });

    test('tryParses hp/ac when Foundry stores them as strings', () {
      final json = jsonEncode({
        'name': 'String Stats',
        'type': 'character',
        'system': {
          'attributes': {
            'hp': {'value': '30', 'max': '40'},
            'ac': {'value': '15'},
          },
        },
      });

      final result = FoundryParser.parse(json);
      expect(result.hpCurrent, 30);
      expect(result.hpMax, 40);
      expect(result.ac, 15);
    });

    test('falls back to defaults when hp/ac values are unparseable', () {
      final json = jsonEncode({
        'name': 'Garbled',
        'type': 'character',
        'system': {
          'attributes': {
            'hp': {'value': 'lots', 'max': 'a bunch'},
            'ac': {'value': 'high'},
          },
        },
      });

      final result = FoundryParser.parse(json);
      expect(result.hpCurrent, 0);
      expect(result.hpMax, 1);
      expect(result.ac, 10);
    });

    test('reports unrecognized top-level fields for future support', () {
      final result = FoundryParser.parse(
        _actorJson(extraTopLevel: {'items': [], 'effects': []}),
      );

      expect(result.unrecognizedFields, containsAll(['items', 'effects']));
    });

    test('known fields are not reported as unrecognized', () {
      final result = FoundryParser.parse(_actorJson());
      expect(result.unrecognizedFields, isEmpty);
    });
  });
}
