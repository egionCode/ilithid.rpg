import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Client client = Client()
  ..setProject('6a43a7b5003097eaaf1f')
  ..setEndpoint('https://appwrite.tuxedorat.com/v1');

class AppwriteService {
  static const String defaultEndpoint = 'https://appwrite.tuxedorat.com/v1';
  static const String defaultProjectId = '6a43a7b5003097eaaf1f';

  static const String _keyEndpoint = 'appwrite_endpoint';
  static const String _keyProjectId = 'appwrite_project_id';

  /// Initializes the client configuration from local storage.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString(_keyEndpoint) ?? defaultEndpoint;
    final projectId = prefs.getString(_keyProjectId) ?? defaultProjectId;
    
    client
      .setEndpoint(endpoint)
      .setProject(projectId);
  }

  /// Saves new configuration and updates the global client.
  static Future<void> saveConfig(String endpoint, String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndpoint, endpoint);
    await prefs.setString(_keyProjectId, projectId);
    
    client
      .setEndpoint(endpoint)
      .setProject(projectId);
  }

  /// Gets the currently saved endpoint.
  static Future<String> getSavedEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEndpoint) ?? defaultEndpoint;
  }

  /// Gets the currently saved project ID.
  static Future<String> getSavedProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProjectId) ?? defaultProjectId;
  }

  /// Verifies connection by making a ping request.
  static Future<bool> testConnection(String endpoint, String projectId) async {
    try {
      final testClient = Client()
        ..setEndpoint(endpoint)
        ..setProject(projectId);
      await testClient.ping();
      return true;
    } catch (_) {
      return false;
    }
  }
}
