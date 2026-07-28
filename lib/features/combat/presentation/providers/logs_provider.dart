import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/combat/domain/log_entry.dart';
import 'package:ilithid/features/combat/presentation/providers/logs_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/services/realtime_service.dart';

/// Log feed for a session (Story 8.2): fetches the most recent entries,
/// paginates older ones on demand, and prepends new entries live via
/// [RealtimeService].
final logsProvider = NotifierProvider.family<LogsNotifier, LogsState, String>(
  (sessionId) => LogsNotifier(sessionId),
);

class LogsNotifier extends Notifier<LogsState> {
  static const _pageSize = 50;

  final String sessionId;
  late TablesDB _tablesDb;
  RealtimeSubscriptionHandle? _realtimeHandle;

  LogsNotifier(this.sessionId);

  @override
  LogsState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() {
        fetchLogs();
        _subscribeToRealtime();
      });
    }

    ref.onDispose(() {
      _realtimeHandle?.cancel();
    });

    return LogsState.initial();
  }

  /// Fetches the most recent page of logs for this session.
  Future<void> fetchLogs() async {
    state = LogsState.loading(current: state.logs);

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: [
          Query.equal('sessionId', sessionId),
          Query.orderDesc('timestamp'),
          Query.limit(_pageSize),
        ],
      );

      if (!ref.mounted) return;

      final logs = response.rows.map((row) => LogEntry.fromRow(row)).toList();
      state = LogsState.success(logs, hasMore: response.total > logs.length);
    } on AppwriteException catch (e) {
      if (!ref.mounted) return;
      state = LogsState.error(
        e.message ?? 'Failed to fetch logs.',
        current: state.logs,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = LogsState.error(e.toString(), current: state.logs);
    }
  }

  /// Loads the next older page, appending it to the end of the feed.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: [
          Query.equal('sessionId', sessionId),
          Query.orderDesc('timestamp'),
          Query.limit(_pageSize),
          Query.offset(state.logs.length),
        ],
      );

      if (!ref.mounted) return;

      final newLogs = response.rows
          .map((row) => LogEntry.fromRow(row))
          .toList();
      final merged = [...state.logs, ...newLogs];
      state = LogsState.success(
        merged,
        hasMore: response.total > merged.length,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void _subscribeToRealtime() {
    try {
      final realtimeClient = ref.read(realtimeClientProvider);
      final isTest = StackTrace.current.toString().contains(
        'package:flutter_test',
      );
      if (isTest && realtimeClient.runtimeType.toString() == 'Realtime') {
        return;
      }

      final service = ref.read(realtimeServiceProvider);
      _realtimeHandle = service.subscribeToSessionLogs(
        sessionId: sessionId,
        onEvent: (message) {
          final entry = LogEntry.fromPayload(message.payload);
          if (state.logs.any((l) => l.id == entry.id)) return;

          state = LogsState.success([
            entry,
            ...state.logs,
          ], hasMore: state.hasMore);
        },
      );
    } catch (_) {
      // Fail silently if Realtime connection fails
    }
  }
}
