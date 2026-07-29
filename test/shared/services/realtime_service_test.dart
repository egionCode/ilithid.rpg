import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/services/realtime_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRealtime extends Mock implements Realtime {}

class MockRealtimeSubscription extends Mock implements RealtimeSubscription {}

RealtimeMessage _messageWithPayload(Map<String, dynamic> payload) {
  return RealtimeMessage(
    events: const ['databases.*.collections.*.documents.*.update'],
    payload: payload,
    channels: const ['channel'],
    timestamp: DateTime.now().toIso8601String(),
  );
}

void main() {
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockSubscription;
  late StreamController<RealtimeMessage> controller;
  late RealtimeService service;

  setUp(() {
    mockRealtime = MockRealtime();
    mockSubscription = MockRealtimeSubscription();
    controller = StreamController<RealtimeMessage>.broadcast();

    when(() => mockSubscription.stream).thenAnswer((_) => controller.stream);
    when(() => mockSubscription.close).thenReturn(() async {});
    when(() => mockRealtime.subscribe(any())).thenReturn(mockSubscription);

    service = RealtimeService(mockRealtime);
  });

  tearDown(() async {
    await controller.close();
  });

  group('subscribeToCampaignCharacters', () {
    test('subscribes to the characters channel', () {
      service.subscribeToCampaignCharacters(
        memberUserIds: const ['user-1'],
        onEvent: (_) {},
      );

      verify(
        () => mockRealtime.subscribe([
          'databases.$appwriteDatabaseId.collections.$appwriteCharactersTableId.documents',
        ]),
      ).called(1);
    });

    test('forwards events for members and ignores others', () async {
      final received = <RealtimeMessage>[];
      service.subscribeToCampaignCharacters(
        memberUserIds: const ['user-1', 'user-2'],
        onEvent: received.add,
      );

      controller.add(_messageWithPayload({'userId': 'user-1'}));
      controller.add(_messageWithPayload({'userId': 'someone-else'}));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.payload['userId'], 'user-1');
    });
  });

  group('subscribeToSessionNpcInstances', () {
    test('forwards events only for the matching sessionId', () async {
      final received = <RealtimeMessage>[];
      service.subscribeToSessionNpcInstances(
        sessionId: 'session-1',
        onEvent: received.add,
      );

      controller.add(_messageWithPayload({'sessionId': 'session-1'}));
      controller.add(_messageWithPayload({'sessionId': 'session-2'}));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.payload['sessionId'], 'session-1');
    });
  });

  group('subscribeToSessionLogs', () {
    test('subscribes to the logs channel filtered by sessionId', () async {
      final received = <RealtimeMessage>[];
      service.subscribeToSessionLogs(
        sessionId: 'session-1',
        onEvent: received.add,
      );

      verify(
        () => mockRealtime.subscribe([
          'databases.$appwriteDatabaseId.collections.$appwriteLogsTableId.documents',
        ]),
      ).called(1);

      controller.add(_messageWithPayload({'sessionId': 'session-1'}));
      controller.add(_messageWithPayload({'sessionId': 'other'}));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
    });
  });

  group('subscribeToCampaignMembers', () {
    test('forwards events only for the matching campaignId', () async {
      final received = <RealtimeMessage>[];
      service.subscribeToCampaignMembers(
        campaignId: 'campaign-1',
        onEvent: received.add,
      );

      controller.add(_messageWithPayload({'campaignId': 'campaign-1'}));
      controller.add(_messageWithPayload({'campaignId': 'campaign-2'}));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.payload['campaignId'], 'campaign-1');
    });
  });

  group('lifecycle', () {
    test('cancel() cancels the stream and closes the channel', () async {
      var closed = false;
      when(() => mockSubscription.close).thenReturn(() async {
        closed = true;
      });

      final handle = service.subscribeToCampaignMembers(
        campaignId: 'campaign-1',
        onEvent: (_) {},
      );

      await handle.cancel();

      expect(closed, isTrue);
      expect(controller.hasListener, isFalse);
    });
  });
}
