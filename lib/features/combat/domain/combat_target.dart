/// Which collection a [CombatTarget] is backed by, so combat actions know
/// which table to update.
enum CombatTargetKind { character, npcInstance }

/// Unifies [Character] and [NpcInstance] into a single shape so the combat
/// action UI/logic doesn't need to branch on the concrete domain type.
class CombatTarget {
  final CombatTargetKind kind;
  final String id;
  final String name;
  final int hpCurrent;
  final int hpMax;
  final int hpTemp;

  const CombatTarget({
    required this.kind,
    required this.id,
    required this.name,
    required this.hpCurrent,
    required this.hpMax,
    required this.hpTemp,
  });
}
