import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final campaignsProvider = NotifierProvider<CampaignsNotifier, CampaignsState>(
  () {
    return CampaignsNotifier();
  },
);

class CampaignsNotifier extends Notifier<CampaignsState> {
  late TablesDB _tablesDb;

  @override
  CampaignsState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    // Reactively watch authentication state
    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() => fetchCampaigns());
    } else {
      return CampaignsState.initial();
    }

    return CampaignsState.initial();
  }

  /// Generates a random 8-character hex string to serve as hexId.
  String _generateHexId() {
    final random = Random();
    const hexChars = '0123456789abcdef';
    return List.generate(8, (index) => hexChars[random.nextInt(16)]).join();
  }

  /// Fetches all campaigns where the current user is a member.
  Future<void> fetchCampaigns() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CampaignsState.error(
        'User must be logged in to fetch campaigns.',
      );
      return;
    }

    state = CampaignsState.loading(currentCampaigns: state.campaigns);

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        queries: [Query.equal('userId', user.$id)],
      );

      final List<UserCampaign> userCampaigns = [];

      for (final row in response.rows) {
        try {
          final member = CampaignMember.fromRow(row);
          final campaignRow = await _tablesDb.getRow(
            databaseId: appwriteDatabaseId,
            tableId: appwriteCampaignsTableId,
            rowId: member.campaignId,
          );
          final campaign = Campaign.fromRow(campaignRow);
          userCampaigns.add(
            UserCampaign(campaign: campaign, role: member.role),
          );
        } catch (e) {
          // Skip corrupted or deleted campaign rows gracefully
        }
      }

      // Sort campaigns by creation date descending
      userCampaigns.sort(
        (a, b) => b.campaign.createdAt.compareTo(a.campaign.createdAt),
      );

      state = CampaignsState.success(userCampaigns);
    } on AppwriteException catch (e) {
      final errorMsg = e.message ?? 'Failed to fetch campaigns.';
      state = CampaignsState.error(errorMsg, currentCampaigns: state.campaigns);
    } catch (e) {
      state = CampaignsState.error(
        e.toString(),
        currentCampaigns: state.campaigns,
      );
    }
  }

  /// Creates a new campaign and assigns the creator as the Game Master ('gm').
  Future<Campaign?> createCampaign(String name) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CampaignsState.error(
        'User must be logged in to create a campaign.',
      );
      return null;
    }

    state = CampaignsState.loading(currentCampaigns: state.campaigns);

    try {
      final campaignId = ID.unique();
      final hexId = _generateHexId();
      final now = DateTime.now().toIso8601String();

      // 1. Create the campaign document
      final campaignData = {
        'hexId': hexId,
        'name': name,
        'gmUserId': user.$id,
        'status': 'active',
        'createdAt': now,
      };

      final campaignRow = await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignsTableId,
        rowId: campaignId,
        data: campaignData,
      );

      final campaign = Campaign.fromRow(campaignRow);

      // 2. Create the campaign member document for the GM
      final memberId = ID.unique();
      final memberData = {
        'campaignId': campaign.id,
        'userId': user.$id,
        'activeCharacterId': null,
        'role': 'gm',
        'joinedAt': now,
      };

      await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        rowId: memberId,
        data: memberData,
      );

      // 3. Update the state with the new campaign in the list (prepend to keep sorted)
      final userCampaign = UserCampaign(campaign: campaign, role: 'gm');
      final updatedList = List<UserCampaign>.from(state.campaigns)
        ..insert(0, userCampaign);
      state = CampaignsState.success(updatedList, newCampaign: campaign);

      return campaign;
    } on AppwriteException catch (e) {
      final errorMsg = e.message ?? 'Failed to create campaign.';
      state = CampaignsState.error(errorMsg, currentCampaigns: state.campaigns);
      return null;
    } catch (e) {
      state = CampaignsState.error(
        e.toString(),
        currentCampaigns: state.campaigns,
      );
      return null;
    }
  }

  /// Resets the new campaign tracking field.
  void clearNewCampaign() {
    state = state.copyWith(newCampaign: null);
  }

  /// Finds a campaign by its hexId.
  Future<Campaign?> findCampaignByHexId(String hexId) async {
    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignsTableId,
        queries: [Query.equal('hexId', hexId.toLowerCase())],
      );

      if (response.rows.isEmpty) {
        return null;
      }

      return Campaign.fromRow(response.rows.first);
    } catch (e) {
      return null;
    }
  }

  /// Checks if the current user is already a member of the campaign.
  Future<CampaignMember?> checkMembership(String campaignId) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return null;

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        queries: [
          Query.equal('campaignId', campaignId),
          Query.equal('userId', user.$id),
        ],
      );

      if (response.rows.isEmpty) {
        return null;
      }

      return CampaignMember.fromRow(response.rows.first);
    } catch (e) {
      return null;
    }
  }

  /// Joins a campaign as a player with an active character sheet.
  Future<CampaignMember?> joinCampaign({
    required String campaignId,
    required String? activeCharacterId,
  }) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CampaignsState.error(
        'User must be logged in to join campaign.',
        currentCampaigns: state.campaigns,
      );
      return null;
    }

    state = CampaignsState.loading(currentCampaigns: state.campaigns);

    try {
      final memberId = ID.unique();
      final now = DateTime.now().toIso8601String();

      final memberData = {
        'campaignId': campaignId,
        'userId': user.$id,
        'activeCharacterId': activeCharacterId,
        'role': 'player',
        'joinedAt': now,
      };

      final row = await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        rowId: memberId,
        data: memberData,
      );

      final newMember = CampaignMember.fromRow(row);

      // Re-fetch campaigns to ensure list is fresh
      await fetchCampaigns();

      return newMember;
    } on AppwriteException catch (e) {
      final errorMsg = e.message ?? 'Failed to join campaign.';
      state = CampaignsState.error(errorMsg, currentCampaigns: state.campaigns);
      return null;
    } catch (e) {
      state = CampaignsState.error(
        e.toString(),
        currentCampaigns: state.campaigns,
      );
      return null;
    }
  }

  /// Updates the active character of the current user in a campaign.
  Future<bool> updateActiveCharacter({
    required String campaignId,
    required String? activeCharacterId,
  }) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return false;

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        queries: [
          Query.equal('campaignId', campaignId),
          Query.equal('userId', user.$id),
        ],
      );

      if (response.rows.isEmpty) {
        return false;
      }

      final memberRow = response.rows.first;
      await _tablesDb.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        rowId: memberRow.$id,
        data: {'activeCharacterId': activeCharacterId},
      );

      // Re-fetch to update state
      await fetchCampaigns();
      return true;
    } catch (e) {
      return false;
    }
  }
}
