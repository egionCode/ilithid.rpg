import 'package:equatable/equatable.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';

enum NpcTemplatesStatus { initial, loading, success, error }

class NpcTemplatesState extends Equatable {
  final NpcTemplatesStatus status;
  final List<NpcTemplate> templates;
  final String? errorMessage;

  const NpcTemplatesState({
    required this.status,
    required this.templates,
    this.errorMessage,
  });

  factory NpcTemplatesState.initial() {
    return const NpcTemplatesState(
      status: NpcTemplatesStatus.initial,
      templates: [],
    );
  }

  factory NpcTemplatesState.loading({
    List<NpcTemplate> currentTemplates = const [],
  }) {
    return NpcTemplatesState(
      status: NpcTemplatesStatus.loading,
      templates: currentTemplates,
    );
  }

  factory NpcTemplatesState.success(List<NpcTemplate> templates) {
    return NpcTemplatesState(
      status: NpcTemplatesStatus.success,
      templates: templates,
    );
  }

  factory NpcTemplatesState.error(
    String message, {
    List<NpcTemplate> currentTemplates = const [],
  }) {
    return NpcTemplatesState(
      status: NpcTemplatesStatus.error,
      templates: currentTemplates,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [status, templates, errorMessage];
}
