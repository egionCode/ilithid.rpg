import 'package:appwrite/appwrite.dart';

const String _appwriteEndpoint = String.fromEnvironment(
  'APPWRITE_ENDPOINT',
  defaultValue: 'https://appwrite.tuxedorat.com/v1',
);

const String _appwriteProjectId = String.fromEnvironment(
  'APPWRITE_PROJECT_ID',
  defaultValue: '6a43a7b5003097eaaf1f',
);

final Client client = Client()
  ..setEndpoint(_appwriteEndpoint)
  ..setProject(_appwriteProjectId);

const String appwriteDatabaseId = String.fromEnvironment(
  'APPWRITE_DATABASE_ID',
  defaultValue: 'main',
);

const String appwriteProfilesTableId = String.fromEnvironment(
  'APPWRITE_PROFILES_TABLE_ID',
  defaultValue: 'profiles',
);

const String appwriteCampaignsTableId = String.fromEnvironment(
  'APPWRITE_CAMPAIGNS_TABLE_ID',
  defaultValue: 'campaigns',
);

const String appwriteCampaignMembersTableId = String.fromEnvironment(
  'APPWRITE_CAMPAIGN_MEMBERS_TABLE_ID',
  defaultValue: 'campaign_members',
);

class AppwriteService {
  /// Initializes the client (configurations are baked in from environment variables).
  static Future<void> initialize() async {
    // Client is pre-configured via global variable instantiation.
  }
}
