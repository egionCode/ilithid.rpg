import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
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
    return CampaignsState.initial();
  }

  /// Generates a random 8-character hex string to serve as hexId.
  String _generateHexId() {
    final random = Random();
    const hexChars = '0123456789abcdef';
    return List.generate(8, (index) => hexChars[random.nextInt(16)]).join();
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

      // 3. Update the state with the new campaign in the list
      final updatedList = List<Campaign>.from(state.campaigns)..add(campaign);
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
}
