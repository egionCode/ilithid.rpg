import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppwriteService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should return default values when no config is saved', () async {
      final endpoint = await AppwriteService.getSavedEndpoint();
      final projectId = await AppwriteService.getSavedProjectId();

      expect(endpoint, equals(AppwriteService.defaultEndpoint));
      expect(projectId, equals(AppwriteService.defaultProjectId));
    });

    test('should save and update configuration in local storage', () async {
      const customEndpoint = 'https://custom-appwrite.com/v1';
      const customProjectId = 'custom_project_123';

      await AppwriteService.saveConfig(customEndpoint, customProjectId);

      final endpoint = await AppwriteService.getSavedEndpoint();
      final projectId = await AppwriteService.getSavedProjectId();

      expect(endpoint, equals(customEndpoint));
      expect(projectId, equals(customProjectId));
    });
  });
}
