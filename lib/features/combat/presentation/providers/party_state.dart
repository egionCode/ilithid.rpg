import 'package:equatable/equatable.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/characters/domain/character.dart';

enum PartyStatus { initial, loading, success, error }

/// A campaign member paired with their active character, if any.
class PartyMember extends Equatable {
  final CampaignMember member;
  final Character? character;

  const PartyMember({required this.member, this.character});

  @override
  List<Object?> get props => [member, character];
}

class PartyState extends Equatable {
  final PartyStatus status;
  final List<PartyMember> members;
  final String? errorMessage;

  const PartyState({
    required this.status,
    required this.members,
    this.errorMessage,
  });

  factory PartyState.initial() {
    return const PartyState(status: PartyStatus.initial, members: []);
  }

  factory PartyState.loading({List<PartyMember> current = const []}) {
    return PartyState(status: PartyStatus.loading, members: current);
  }

  factory PartyState.success(List<PartyMember> members) {
    return PartyState(status: PartyStatus.success, members: members);
  }

  factory PartyState.error(
    String message, {
    List<PartyMember> current = const [],
  }) {
    return PartyState(
      status: PartyStatus.error,
      members: current,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [status, members, errorMessage];
}
