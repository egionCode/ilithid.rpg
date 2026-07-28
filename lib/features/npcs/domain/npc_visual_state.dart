/// Visual-only health tiers shown to players when the GM hides NPCs' exact
/// HP (Story 7.4), derived from the hpCurrent/hpMax ratio.
enum NpcVisualState {
  healthy, // > 75%
  wounded, // 25% - 75%
  nearDeath, // < 25%, > 0
  dead; // == 0

  static NpcVisualState fromHp(int hpCurrent, int hpMax) {
    if (hpCurrent <= 0) return NpcVisualState.dead;
    if (hpMax <= 0) return NpcVisualState.dead;

    final ratio = hpCurrent / hpMax;
    if (ratio > 0.75) return NpcVisualState.healthy;
    if (ratio >= 0.25) return NpcVisualState.wounded;
    return NpcVisualState.nearDeath;
  }

  String get label {
    switch (this) {
      case NpcVisualState.healthy:
        return 'Saudável';
      case NpcVisualState.wounded:
        return 'Machucado';
      case NpcVisualState.nearDeath:
        return 'Quase Morto';
      case NpcVisualState.dead:
        return 'Morto';
    }
  }
}
