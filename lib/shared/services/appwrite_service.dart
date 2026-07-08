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

const String appwriteCharactersTableId = String.fromEnvironment(
  'APPWRITE_CHARACTERS_TABLE_ID',
  defaultValue: 'characters',
);

const String appwriteSessionsTableId = String.fromEnvironment(
  'APPWRITE_SESSIONS_TABLE_ID',
  defaultValue: 'sessions',
);

const String appwriteNpcTemplatesTableId = String.fromEnvironment(
  'APPWRITE_NPC_TEMPLATES_TABLE_ID',
  defaultValue: 'npc_templates',
);

const String appwriteNpcInstancesTableId = String.fromEnvironment(
  'APPWRITE_NPC_INSTANCES_TABLE_ID',
  defaultValue: 'npc_instances',
);

class AppwriteService {
  /// Initializes the client (configurations are baked in from environment variables).
  static Future<void> initialize() async {
    // Client is pre-configured via global variable instantiation.
  }
}
