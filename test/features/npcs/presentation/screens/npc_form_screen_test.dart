import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
import 'package:ilithid/features/npcs/presentation/screens/npc_form_screen.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockTablesDB extends Mock implements TablesDB {}

class MockRealtime extends Mock implements Realtime {}

class MockRealtimeSubscription extends Mock implements RealtimeSubscription {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  FakeAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

class FakeNpcTemplatesNotifier extends NpcTemplatesNotifier {
  final NpcTemplatesState _initialState;
  FakeNpcTemplatesNotifier(this._initialState);

  @override
  NpcTemplatesState build() => _initialState;

  @override
  Future<NpcTemplate?> createNpcTemplate(
    String name,
    int hpMax,
    int ac, {
    String sourceSystem = 'manual',
    bool isPublic = true,
  }) async {
    return NpcTemplate(
      id: 'npc_new_123',
      creatorId: 'user_123',
      name: name,
      hpMax: hpMax,
      ac: ac,
      sourceSystem: sourceSystem,
      isPublic: isPublic,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  late MockTablesDB mockTablesDb;
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockRealtimeSubscription;

  final authUser = models.User.fromMap({
    '\$id': 'user_123',
    '\$createdAt': '',
    '\$updatedAt': '',
    'name': 'Grog',
    'email': 'grog@vox.com',
    'phone': '',
    'emailVerification': false,
    'phoneVerification': false,
    'status': true,
    'labels': <String>[],
    'passwordUpdate': '',
    'mfa': false,
    'prefs': <String, dynamic>{},
    'accessedAt': '',
    'registration': '',
    'targets': <Map<String, dynamic>>[],
  });

  final authState = AuthState(
    status: AuthStatus.authenticated,
    user: authUser,
    displayName: 'Grog',
  );

  setUp(() {
    mockTablesDb = MockTablesDB();
    mockRealtime = MockRealtime();
    mockRealtimeSubscription = MockRealtimeSubscription();

    when(
      () => mockRealtime.subscribe(any()),
    ).thenReturn(mockRealtimeSubscription);
    when(
      () => mockRealtimeSubscription.stream,
    ).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('NpcFormScreen validation and creation works', (tester) async {
    final templatesState = NpcTemplatesState.success(const []);

    final router = GoRouter(
      initialLocation: '/npcs/new',
      routes: [
        GoRoute(
          path: '/npcs/new',
          builder: (context, state) => const NpcFormScreen(),
        ),
        GoRoute(
          path: '/npcs',
          builder: (context, state) =>
              const Scaffold(body: Text('NPC Library')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          npcTemplatesProvider.overrideWith(
            () => FakeNpcTemplatesNotifier(templatesState),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Form inputs and submit button are present
    expect(find.byKey(const Key('npc_name_field')), findsOneWidget);
    expect(find.byKey(const Key('npc_hp_field')), findsOneWidget);
    expect(find.byKey(const Key('npc_ac_field')), findsOneWidget);
    expect(find.byKey(const Key('npc_system_field')), findsOneWidget);
    expect(find.byKey(const Key('npc_submit_button')), findsOneWidget);

    // Clear name and trigger validation
    await tester.enterText(find.byKey(const Key('npc_name_field')), '');
    await tester.tap(find.byKey(const Key('npc_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('O nome do NPC é obrigatório'), findsOneWidget);

    // Fill valid data
    await tester.enterText(
      find.byKey(const Key('npc_name_field')),
      'Goblin Chief',
    );
    await tester.enterText(find.byKey(const Key('npc_hp_field')), '24');
    await tester.enterText(find.byKey(const Key('npc_ac_field')), '15');

    // Tap submit
    await tester.tap(find.byKey(const Key('npc_submit_button')));
    await tester.pumpAndSettle();

    // Verify it redirects back to list and shows success toast/snackbar
    expect(
      find.text('Template de NPC "Goblin Chief" criado com sucesso!'),
      findsOneWidget,
    );
  });
}
