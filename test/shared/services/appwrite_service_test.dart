import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppwriteService Unit Tests', () {
    test(
      'client should be initialized with default or environment endpoint',
      () {
        expect(client.endPoint, isNotEmpty);
      },
    );
  });
}
