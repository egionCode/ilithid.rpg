/// Pure HP arithmetic rules shared by GM and player combat actions.
class CombatMath {
  const CombatMath._();

  /// Damage never takes hpCurrent below zero.
  static int applyDamage(int hpCurrent, int amount) {
    final result = hpCurrent - amount;
    return result < 0 ? 0 : result;
  }

  /// Healing never takes hpCurrent above hpMax.
  static int applyHeal(int hpCurrent, int hpMax, int amount) {
    final result = hpCurrent + amount;
    return result > hpMax ? hpMax : result;
  }

  /// Temporary HP is tracked separately from hpCurrent/hpMax and never
  /// goes below zero.
  static int applyTempHp(int hpTemp, int amount) {
    final result = hpTemp + amount;
    return result < 0 ? 0 : result;
  }
}
