import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/combat/presentation/providers/party_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/services/realtime_service.dart';

/// Lists every member of a campaign together with their active character,
/// so the GM combat panel (Story 7.2) and the group view (Story 7.4) can
/// show live HP for the whole party.
final partyProvider =
    NotifierProvider.family<PartyNotifier, PartyState, String>(
      (campaignId) => PartyNotifier(campaignId),
    );

class PartyNotifier extends Notifier<PartyState> {
  final String campaignId;
  late TablesDB _tablesDb;
  RealtimeSubscriptionHandle? _membersHandle;
  RealtimeSubscriptionHandle? _charactersHandle;

  PartyNotifier(this.campaignId);

  @override
  PartyState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() {
        fetchParty();
        _subscribeToMembers();
      });
    }

    ref.onDispose(() {
      _membersHandle?.cancel();
      _charactersHandle?.cancel();
    });

    return PartyState.initial();
  }

  /// Fetches all members of the campaign and their active characters.
  Future<void> fetchParty() async {
    state = PartyState.loading(current: state.members);

    try {
      final membersResponse = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        queries: [Query.equal('campaignId', campaignId)],
      );

      final members = membersResponse.rows
          .map((row) => CampaignMember.fromRow(row))
          .toList();

      final characterIds = members
          .map((m) => m.activeCharacterId)
          .whereType<String>()
          .toList();

      final charactersById = <String, Character>{};
      if (characterIds.isNotEmpty) {
        final charactersResponse = await _tablesDb.listRows(
          databaseId: appwriteDatabaseId,
          tableId: appwriteCharactersTableId,
          queries: [Query.equal(r'$id', characterIds)],
        );
        for (final row in charactersResponse.rows) {
          final character = Character.fromRow(row);
          charactersById[character.id] = character;
        }
      }

      if (!ref.mounted) return;

      final partyMembers = members
          .map(
            (m) => PartyMember(
              member: m,
              character: m.activeCharacterId != null
                  ? charactersById[m.activeCharacterId]
                  : null,
            ),
          )
          .toList();

      state = PartyState.success(partyMembers);
      _subscribeToCharacters(members.map((m) => m.userId).toList());
    } on AppwriteException catch (e) {
      if (!ref.mounted) return;
      state = PartyState.error(
        e.message ?? 'Failed to fetch party.',
        current: state.members,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = PartyState.error(e.toString(), current: state.members);
    }
  }

  void _subscribeToMembers() {
    try {
      final service = ref.read(realtimeServiceProvider);
      _membersHandle = service.subscribeToCampaignMembers(
        campaignId: campaignId,
        onEvent: (_) => fetchParty(),
      );
    } catch (_) {
      // Fail silently if Realtime connection fails
    }
  }

  void _subscribeToCharacters(List<String> memberUserIds) {
    unawaited(_charactersHandle?.cancel());
    try {
      final service = ref.read(realtimeServiceProvider);
      _charactersHandle = service.subscribeToCampaignCharacters(
        memberUserIds: memberUserIds,
        onEvent: (_) => fetchParty(),
      );
    } catch (_) {
      // Fail silently if Realtime connection fails
    }
  }
}
