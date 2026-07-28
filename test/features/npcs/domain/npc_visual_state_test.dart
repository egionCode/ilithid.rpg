import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/npcs/domain/npc_visual_state.dart';

void main() {
  group('NpcVisualState.fromHp', () {
    test('above 75% is healthy', () {
      expect(NpcVisualState.fromHp(80, 100), NpcVisualState.healthy);
      expect(NpcVisualState.fromHp(76, 100), NpcVisualState.healthy);
    });

    test('between 25% and 75% (inclusive) is wounded', () {
      expect(NpcVisualState.fromHp(75, 100), NpcVisualState.wounded);
      expect(NpcVisualState.fromHp(50, 100), NpcVisualState.wounded);
      expect(NpcVisualState.fromHp(25, 100), NpcVisualState.wounded);
    });

    test('below 25% (but above zero) is nearDeath', () {
      expect(NpcVisualState.fromHp(24, 100), NpcVisualState.nearDeath);
      expect(NpcVisualState.fromHp(1, 100), NpcVisualState.nearDeath);
    });

    test('zero HP is dead', () {
      expect(NpcVisualState.fromHp(0, 100), NpcVisualState.dead);
    });

    test('negative or zero hpMax is treated as dead', () {
      expect(NpcVisualState.fromHp(5, 0), NpcVisualState.dead);
    });
  });

  group('NpcVisualState.label', () {
    test('has a Portuguese label for each state', () {
      expect(NpcVisualState.healthy.label, 'Saudável');
      expect(NpcVisualState.wounded.label, 'Machucado');
      expect(NpcVisualState.nearDeath.label, 'Quase Morto');
      expect(NpcVisualState.dead.label, 'Morto');
    });
  });
}
