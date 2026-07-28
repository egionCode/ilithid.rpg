import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

/// Dedicated [Realtime] client for [RealtimeService], separate from
/// feature-level providers to avoid shared/ depending on features/.
final realtimeClientProvider = Provider<Realtime>((ref) => Realtime(client));

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(ref.watch(realtimeClientProvider));
});

/// Handle returned by [RealtimeService] subscriptions. Cancelling it both
/// stops the local stream listener and closes the underlying Appwrite
/// Realtime channel, so callers get a single lifecycle hook to dispose.
class RealtimeSubscriptionHandle {
  RealtimeSubscriptionHandle(this._streamSubscription, this._close);

  final StreamSubscription<RealtimeMessage> _streamSubscription;
  final Future<void> Function() _close;

  Future<void> cancel() async {
    await _streamSubscription.cancel();
    await _close();
  }
}

/// Centralizes Appwrite Realtime subscriptions for collections that need
/// live updates across features (characters, npc_instances, logs,
/// campaign_members), so each feature doesn't duplicate channel/filter logic.
class RealtimeService {
  RealtimeService(this._realtime);

  final Realtime _realtime;

  /// Subscribes to `characters` updates for the given campaign member user IDs.
  RealtimeSubscriptionHandle subscribeToCampaignCharacters({
    required List<String> memberUserIds,
    required void Function(RealtimeMessage message) onEvent,
  }) {
    return _subscribe(
      tableId: appwriteCharactersTableId,
      onEvent: onEvent,
      matches: (payload) => memberUserIds.contains(payload['userId']),
    );
  }

  /// Subscribes to `npc_instances` updates for the given session.
  RealtimeSubscriptionHandle subscribeToSessionNpcInstances({
    required String sessionId,
    required void Function(RealtimeMessage message) onEvent,
  }) {
    return _subscribe(
      tableId: appwriteNpcInstancesTableId,
      onEvent: onEvent,
      matches: (payload) => payload['sessionId'] == sessionId,
    );
  }

  /// Subscribes to `logs` updates for the given session.
  RealtimeSubscriptionHandle subscribeToSessionLogs({
    required String sessionId,
    required void Function(RealtimeMessage message) onEvent,
  }) {
    return _subscribe(
      tableId: appwriteLogsTableId,
      onEvent: onEvent,
      matches: (payload) => payload['sessionId'] == sessionId,
    );
  }

  /// Subscribes to `campaign_members` updates for the given campaign.
  RealtimeSubscriptionHandle subscribeToCampaignMembers({
    required String campaignId,
    required void Function(RealtimeMessage message) onEvent,
  }) {
    return _subscribe(
      tableId: appwriteCampaignMembersTableId,
      onEvent: onEvent,
      matches: (payload) => payload['campaignId'] == campaignId,
    );
  }

  RealtimeSubscriptionHandle _subscribe({
    required String tableId,
    required void Function(RealtimeMessage message) onEvent,
    required bool Function(Map<String, dynamic> payload) matches,
  }) {
    final channel =
        'databases.$appwriteDatabaseId.collections.$tableId.documents';
    final subscription = _realtime.subscribe([channel]);

    return RealtimeSubscriptionHandle(
      subscription.stream
          .where((message) => matches(message.payload))
          .listen(onEvent),
      subscription.close,
    );
  }
}
