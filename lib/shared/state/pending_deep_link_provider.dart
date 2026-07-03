import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a pending deep link URL (e.g., '/join/ABC123') while the user logs in.
/// After successful authentication the router will navigate to this URL
/// and then clear the provider.
class PendingDeepLinkNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? url) => state = url;
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkNotifier, String?>(
      PendingDeepLinkNotifier.new,
    );
