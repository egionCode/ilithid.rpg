// Immutable state for the NPC template library (Story 6.2).
// Depends on: NpcTemplate domain model.
import 'package:equatable/equatable.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';

enum NpcTemplatesStatus { initial, loading, success, error }

class NpcTemplatesState extends Equatable {
  final NpcTemplatesStatus status;
  final List<NpcTemplate> publicTemplates;
  final List<NpcTemplate> myTemplates;
  // Maps creatorId -> displayName, resolved lazily from the profiles table
  // (Appwrite has no join, so names are fetched separately from templates).
  final Map<String, String> creatorNames;
  final String? errorMessage;

  const NpcTemplatesState({
    required this.status,
    required this.publicTemplates,
    required this.myTemplates,
    this.creatorNames = const {},
    this.errorMessage,
  });

  factory NpcTemplatesState.initial() {
    return const NpcTemplatesState(
      status: NpcTemplatesStatus.initial,
      publicTemplates: [],
      myTemplates: [],
    );
  }

  factory NpcTemplatesState.loading({
    List<NpcTemplate> currentPublicTemplates = const [],
    List<NpcTemplate> currentMyTemplates = const [],
    Map<String, String> currentCreatorNames = const {},
  }) {
    return NpcTemplatesState(
      status: NpcTemplatesStatus.loading,
      publicTemplates: currentPublicTemplates,
      myTemplates: currentMyTemplates,
      creatorNames: currentCreatorNames,
    );
  }

  factory NpcTemplatesState.success({
    required List<NpcTemplate> publicTemplates,
    required List<NpcTemplate> myTemplates,
    Map<String, String> creatorNames = const {},
  }) {
    return NpcTemplatesState(
      status: NpcTemplatesStatus.success,
      publicTemplates: publicTemplates,
      myTemplates: myTemplates,
      creatorNames: creatorNames,
    );
  }

  factory NpcTemplatesState.error(
    String message, {
    List<NpcTemplate> currentPublicTemplates = const [],
    List<NpcTemplate> currentMyTemplates = const [],
    Map<String, String> currentCreatorNames = const {},
  }) {
    return NpcTemplatesState(
      status: NpcTemplatesStatus.error,
      publicTemplates: currentPublicTemplates,
      myTemplates: currentMyTemplates,
      creatorNames: currentCreatorNames,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    publicTemplates,
    myTemplates,
    creatorNames,
    errorMessage,
  ];
}
