import 'package:equatable/equatable.dart';
import 'package:ilithid/features/npcs/domain/npc_instance.dart';

enum NpcInstancesStatus { initial, loading, success, error }

class NpcInstancesState extends Equatable {
  final NpcInstancesStatus status;
  final List<NpcInstance> npcInstances;
  final String? errorMessage;

  const NpcInstancesState({
    required this.status,
    required this.npcInstances,
    this.errorMessage,
  });

  factory NpcInstancesState.initial() {
    return const NpcInstancesState(
      status: NpcInstancesStatus.initial,
      npcInstances: [],
    );
  }

  factory NpcInstancesState.loading({
    List<NpcInstance> currentInstances = const [],
  }) {
    return NpcInstancesState(
      status: NpcInstancesStatus.loading,
      npcInstances: currentInstances,
    );
  }

  factory NpcInstancesState.success(List<NpcInstance> npcInstances) {
    return NpcInstancesState(
      status: NpcInstancesStatus.success,
      npcInstances: npcInstances,
    );
  }

  factory NpcInstancesState.error(
    String message, {
    List<NpcInstance> currentInstances = const [],
  }) {
    return NpcInstancesState(
      status: NpcInstancesStatus.error,
      npcInstances: currentInstances,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [status, npcInstances, errorMessage];
}
