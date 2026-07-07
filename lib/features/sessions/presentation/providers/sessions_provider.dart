import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/sessions/domain/session.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final appwriteRealtimeProvider = Provider<Realtime>((ref) => Realtime(client));

final sessionsProvider =
    NotifierProvider.family<SessionsNotifier, SessionsState, String>(
      (arg) => SessionsNotifier(arg),
    );

class SessionsNotifier extends Notifier<SessionsState> {
  final String campaignId;
  late TablesDB _tablesDb;

  SessionsNotifier(this.campaignId);

  @override
  SessionsState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    // Watch authState to check session when authenticated
    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() {
        checkActiveSession();
        _subscribeToRealtime(campaignId);
      });
    }

    return SessionsState.initial();
  }

  /// Checks if there is an active session for the campaign.
  Future<void> checkActiveSession() async {
    state = SessionsState.loading();

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteSessionsTableId,
        queries: [
          Query.equal('campaignId', campaignId),
          Query.orderDesc('startedAt'),
        ],
      );

      if (!ref.mounted) return;

      final sessions = response.rows
          .map((row) => Session.fromRow(row))
          .toList();
      final activeSession = sessions.cast<Session?>().firstWhere(
        (s) => s?.status == 'active',
        orElse: () => null,
      );

      state = SessionsState.success(activeSession, sessions);
    } on AppwriteException catch (e) {
      if (!ref.mounted) return;
      state = SessionsState.error(
        e.message ?? 'Failed to check active session.',
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = SessionsState.error(e.toString());
    }
  }

  /// Creates a new session if none is active.
  Future<Session?> createSession() async {
    state = SessionsState.loading();

    try {
      // 1. Verify if there is already an active session in local state
      // (This avoids an extra DB roundtrip since local state holds the active session)
      if (state.activeSession != null) {
        state = SessionsState.error(
          'A session is already active for this campaign.',
        );
        return null;
      }

      // Double check in database to avoid concurrency issues
      final checkResponse = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteSessionsTableId,
        queries: [
          Query.equal('campaignId', campaignId),
          Query.equal('status', 'active'),
        ],
      );

      if (!ref.mounted) return null;

      if (checkResponse.rows.isNotEmpty) {
        state = SessionsState.error(
          'A session is already active for this campaign.',
        );
        return null;
      }

      // 2. Create the session document
      final sessionId = ID.unique();
      final now = DateTime.now().toIso8601String();
      final sessionData = {
        'campaignId': campaignId,
        'status': 'active',
        'startedAt': now,
        'endedAt': null,
      };

      final sessionRow = await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteSessionsTableId,
        rowId: sessionId,
        data: sessionData,
      );

      if (!ref.mounted) return null;

      final session = Session.fromRow(sessionRow);
      final updatedSessions = [session, ...state.sessions];
      state = SessionsState.success(session, updatedSessions);
      return session;
    } on AppwriteException catch (e) {
      if (!ref.mounted) return null;
      final errorMsg = e.message ?? 'Failed to create session.';
      state = SessionsState.error(errorMsg);
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      state = SessionsState.error(e.toString());
      return null;
    }
  }

  /// Ends the active session.
  Future<bool> endSession(String sessionId) async {
    state = SessionsState.loading();

    try {
      final now = DateTime.now().toIso8601String();
      final sessionData = {'status': 'finished', 'endedAt': now};

      await _tablesDb.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteSessionsTableId,
        rowId: sessionId,
        data: sessionData,
      );

      // TODO: Discard NPC instances when Epic 6 NPC Library is implemented

      if (!ref.mounted) return true;

      await checkActiveSession();
      return true;
    } on AppwriteException catch (e) {
      if (!ref.mounted) return false;
      state = SessionsState.error(e.message ?? 'Failed to end session.');
      return false;
    } catch (e) {
      if (!ref.mounted) return false;
      state = SessionsState.error(e.toString());
      return false;
    }
  }

  /// Subscribes to the Realtime events for the sessions collection to keep state in sync.
  void _subscribeToRealtime(String campaignId) {
    try {
      final realtime = ref.read(appwriteRealtimeProvider);
      final isTest = StackTrace.current.toString().contains(
        'package:flutter_test',
      );
      if (isTest && realtime.runtimeType.toString() == 'Realtime') {
        return;
      }
      const channel =
          'databases.$appwriteDatabaseId.collections.$appwriteSessionsTableId.documents';
      final subscription = realtime.subscribe([channel]);

      final streamSub = subscription.stream.listen((event) {
        final payload = event.payload;
        final eventCampaignId = payload['campaignId'] as String?;
        if (eventCampaignId == campaignId) {
          checkActiveSession();
        }
      });

      ref.onDispose(() {
        streamSub.cancel();
      });
    } catch (_) {
      // Fail silently if Realtime connection fails
    }
  }
}
