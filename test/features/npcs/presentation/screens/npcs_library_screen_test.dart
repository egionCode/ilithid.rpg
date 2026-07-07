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
import 'package:ilithid/features/npcs/presentation/screens/npcs_library_screen.dart';
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

  testWidgets('NpcsLibraryScreen renders loading state', (tester) async {
    final loadingState = NpcTemplatesState.loading();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          npcTemplatesProvider.overrideWith(
            () => FakeNpcTemplatesNotifier(loadingState),
          ),
        ],
        child: const MaterialApp(home: NpcsLibraryScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('NpcsLibraryScreen renders empty state', (tester) async {
    final emptyState = NpcTemplatesState.success(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          npcTemplatesProvider.overrideWith(
            () => FakeNpcTemplatesNotifier(emptyState),
          ),
        ],
        child: const MaterialApp(home: NpcsLibraryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Nenhum NPC encontrado'), findsOneWidget);
  });

  testWidgets(
    'NpcsLibraryScreen renders success list state and FAB navigates',
    (tester) async {
      final templates = [
        NpcTemplate(
          id: 'npc_1',
          creatorId: 'user_123',
          name: 'Goblin Scout',
          hpMax: 8,
          ac: 12,
          sourceSystem: 'dnd5e',
          createdAt: DateTime.now(),
        ),
      ];

      final successState = NpcTemplatesState.success(templates);

      final router = GoRouter(
        initialLocation: '/npcs',
        routes: [
          GoRoute(
            path: '/npcs',
            builder: (context, state) => const NpcsLibraryScreen(),
          ),
          GoRoute(
            path: '/npcs/new',
            builder: (context, state) => const Scaffold(body: Text('New Form')),
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
              () => FakeNpcTemplatesNotifier(successState),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(find.text('Goblin Scout'), findsOneWidget);
      expect(find.text('HP Máx: 8 | CA: 12'), findsOneWidget);

      // Tap FAB to navigate to form
      await tester.tap(find.byKey(const Key('add_npc_template_fab')));
      await tester.pumpAndSettle();

      expect(find.text('New Form'), findsOneWidget);
    },
  );
}
