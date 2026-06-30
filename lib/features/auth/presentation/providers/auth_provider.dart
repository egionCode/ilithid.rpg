import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final appwriteAccountProvider = Provider<Account>((ref) => Account(client));
final appwriteDatabasesProvider = Provider<Databases>(
  (ref) => Databases(client),
);

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  late Account _account;
  late Databases _databases;

  @override
  AuthState build() {
    _account = ref.watch(appwriteAccountProvider);
    _databases = ref.watch(appwriteDatabasesProvider);
    // Check session on startup.
    checkSession();
    return AuthState.initial();
  }

  AuthState get debugState => state;

  Future<void> checkSession() async {
    try {
      final user = await _account.get();

      // Attempt to retrieve the profile document
      String displayName = user.name;
      try {
        final profile = await _databases.getDocument(
          databaseId: appwriteDatabaseId,
          collectionId: appwriteProfilesCollectionId,
          documentId: user.$id,
        );
        displayName = (profile.data['displayName'] as String?) ?? user.name;
      } catch (_) {
        // If profile doesn't exist, we fallback to user.name
      }

      state = AuthState.authenticated(user, displayName);
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    try {
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await _account.get();

      // Retrieve display name from profile collection
      String displayName = user.name;
      try {
        final profile = await _databases.getDocument(
          databaseId: appwriteDatabaseId,
          collectionId: appwriteProfilesCollectionId,
          documentId: user.$id,
        );
        displayName = (profile.data['displayName'] as String?) ?? user.name;
      } catch (_) {
        // Fallback to name from Auth account
      }

      state = AuthState.authenticated(user, displayName);
    } on AppwriteException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
    } catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.toString());
    }
  }

  Future<void> register(
    String displayName,
    String email,
    String password,
  ) async {
    state = AuthState.loading();
    try {
      final userId = ID.unique();
      await _account.create(
        userId: userId,
        email: email,
        password: password,
        name: displayName,
      );

      // Auto login
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await _account.get();

      // Create profile document
      try {
        await _databases.createDocument(
          databaseId: appwriteDatabaseId,
          collectionId: appwriteProfilesCollectionId,
          documentId: user.$id,
          data: <String, dynamic>{
            'userId': user.$id,
            'displayName': displayName,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (_) {
        // Even if document creation fails, we logged in successfully
      }

      state = AuthState.authenticated(user, displayName);
    } on AppwriteException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
    } catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    try {
      await _account.deleteSession(sessionId: 'current');
      state = AuthState.unauthenticated();
    } on AppwriteException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
    } catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.toString());
    }
  }
}
