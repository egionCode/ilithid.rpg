import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/combat/domain/combat_math.dart';

void main() {
  group('CombatMath.applyDamage', () {
    test('subtracts the amount from hpCurrent', () {
      expect(CombatMath.applyDamage(20, 5), 15);
    });

    test('never goes below zero', () {
      expect(CombatMath.applyDamage(3, 10), 0);
    });

    test('exact lethal damage results in zero', () {
      expect(CombatMath.applyDamage(10, 10), 0);
    });
  });

  group('CombatMath.applyHeal', () {
    test('adds the amount to hpCurrent', () {
      expect(CombatMath.applyHeal(10, 20, 5), 15);
    });

    test('never exceeds hpMax', () {
      expect(CombatMath.applyHeal(18, 20, 10), 20);
    });

    test('healing at full HP stays at hpMax', () {
      expect(CombatMath.applyHeal(20, 20, 5), 20);
    });
  });

  group('CombatMath.applyTempHp', () {
    test('adds the amount to hpTemp', () {
      expect(CombatMath.applyTempHp(0, 8), 8);
    });

    test('accumulates on top of existing temp HP', () {
      expect(CombatMath.applyTempHp(5, 3), 8);
    });

    test('never goes below zero', () {
      expect(CombatMath.applyTempHp(2, -10), 0);
    });
  });
}
