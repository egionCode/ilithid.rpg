import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAccount extends Mock implements Account {}

class MockDatabases extends Mock implements Databases {}

void main() {
  late MockAccount mockAccount;
  late MockDatabases mockDatabases;
  late ProviderContainer container;

  setUp(() {
    mockAccount = MockAccount();
    mockDatabases = MockDatabases();

    container = ProviderContainer(
      overrides: [
        appwriteAccountProvider.overrideWithValue(mockAccount),
        appwriteDatabasesProvider.overrideWithValue(mockDatabases),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthNotifier Tests with Riverpod Container', () {
    test(
      'checkSession should set authenticated state when session exists',
      () async {
        final user = models.User.fromMap({
          '\$id': 'user_123',
          '\$createdAt': '',
          '\$updatedAt': '',
          'name': 'Legolas',
          'email': 'legolas@rivendell.com',
          'phone': '',
          'emailVerification': false,
          'phoneVerification': false,
          'status': true,
          'labels': <String>[],
          'passwordUpdate': '',
          'registration': '',
          'accessedAt': '',
          'prefs': <String, dynamic>{},
          'mfa': false,
          'targets': <Map<String, dynamic>>[],
        });

        final document = models.Document.fromMap({
          '\$id': 'user_123',
          '\$collectionId': 'profiles',
          '\$databaseId': 'main',
          '\$createdAt': '',
          '\$updatedAt': '',
          '\$permissions': <String>[],
          '\$sequence': 0,
          'displayName': 'Legolas',
        });

        when(() => mockAccount.get()).thenAnswer((_) async => user);
        when(
          () => mockDatabases.getDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
          ),
        ).thenAnswer((_) async => document);

        // Trigger session check manually since our setup overrides the providers
        await container.read(authProvider.notifier).checkSession();

        final state = container.read(authProvider);
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.displayName, equals('Legolas'));
        expect(state.user?.email, equals('legolas@rivendell.com'));
      },
    );

    test(
      'checkSession should set unauthenticated state when no session exists',
      () async {
        when(
          () => mockAccount.get(),
        ).thenThrow(AppwriteException('No session', 401));

        await container.read(authProvider.notifier).checkSession();

        final state = container.read(authProvider);
        expect(state.status, equals(AuthStatus.unauthenticated));
      },
    );

    test('login should set authenticated state on success', () async {
      final user = models.User.fromMap({
        '\$id': 'user_123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Gimli',
        'email': 'gimli@erebor.com',
        'phone': '',
        'emailVerification': false,
        'phoneVerification': false,
        'status': true,
        'labels': <String>[],
        'passwordUpdate': '',
        'registration': '',
        'accessedAt': '',
        'prefs': <String, dynamic>{},
        'mfa': false,
        'targets': <Map<String, dynamic>>[],
      });

      final session = models.Session.fromMap({
        '\$id': 'session_123',
        '\$createdAt': '',
        'userId': 'user_123',
        'expire': '',
        'provider': '',
        'providerUid': '',
        'providerAccessToken': '',
        'providerAccessTokenExpiry': '',
        'providerRefreshToken': '',
        'ip': '',
        'osCode': '',
        'osName': '',
        'osVersion': '',
        'clientType': '',
        'clientCode': '',
        'clientName': '',
        'clientVersion': '',
        'deviceBrand': '',
        'deviceModel': '',
        'deviceName': '',
        'deviceType': '',
        'current': true,
      });

      when(
        () => mockAccount.createEmailPasswordSession(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => session);

      when(() => mockAccount.get()).thenAnswer((_) async => user);
      when(
        () => mockDatabases.getDocument(
          databaseId: any(named: 'databaseId'),
          collectionId: any(named: 'collectionId'),
          documentId: any(named: 'documentId'),
        ),
      ).thenThrow(AppwriteException('No profile', 404));

      await container
          .read(authProvider.notifier)
          .login('gimli@erebor.com', 'moria_rules');

      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.displayName, equals('Gimli'));
    });

    test('login should set unauthenticated state on failure', () async {
      when(
        () => mockAccount.createEmailPasswordSession(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AppwriteException('Login failed', 401));

      await container
          .read(authProvider.notifier)
          .login('gimli@erebor.com', 'wrong_pass');

      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.errorMessage, equals('Login failed'));
    });

    test('register should register and auto-login', () async {
      final user = models.User.fromMap({
        '\$id': 'user_123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Aragorn',
        'email': 'aragorn@gondor.com',
        'phone': '',
        'emailVerification': false,
        'phoneVerification': false,
        'status': true,
        'labels': <String>[],
        'passwordUpdate': '',
        'registration': '',
        'accessedAt': '',
        'prefs': <String, dynamic>{},
        'mfa': false,
        'targets': <Map<String, dynamic>>[],
      });

      final session = models.Session.fromMap({
        '\$id': 'session_123',
        '\$createdAt': '',
        'userId': 'user_123',
        'expire': '',
        'provider': '',
        'providerUid': '',
        'providerAccessToken': '',
        'providerAccessTokenExpiry': '',
        'providerRefreshToken': '',
        'ip': '',
        'osCode': '',
        'osName': '',
        'osVersion': '',
        'clientType': '',
        'clientCode': '',
        'clientName': '',
        'clientVersion': '',
        'deviceBrand': '',
        'deviceModel': '',
        'deviceName': '',
        'deviceType': '',
        'current': true,
      });

      final document = models.Document.fromMap({
        '\$id': 'user_123',
        '\$collectionId': 'profiles',
        '\$databaseId': 'main',
        '\$createdAt': '',
        '\$updatedAt': '',
        '\$permissions': <String>[],
        '\$sequence': 0,
        'displayName': 'Aragorn',
      });

      when(
        () => mockAccount.create(
          userId: any(named: 'userId'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => user);

      when(
        () => mockAccount.createEmailPasswordSession(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => session);

      when(() => mockAccount.get()).thenAnswer((_) async => user);

      when(
        () => mockDatabases.createDocument(
          databaseId: any(named: 'databaseId'),
          collectionId: any(named: 'collectionId'),
          documentId: any(named: 'documentId'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => document);

      await container
          .read(authProvider.notifier)
          .register('Aragorn', 'aragorn@gondor.com', 'isildur_heir');

      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.displayName, equals('Aragorn'));
    });

    test('logout should reset state to unauthenticated', () async {
      when(
        () => mockAccount.deleteSession(sessionId: any(named: 'sessionId')),
      ).thenAnswer((_) async => true);
      await container.read(authProvider.notifier).logout();

      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
    });
  });
}
