import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_state.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/features/dashboard/presentation/screens/campaign_dashboard_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MockTablesDB extends Mock implements TablesDB {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  FakeAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

class FakeCampaignsNotifier extends CampaignsNotifier {
  final CampaignsState _initialState;
  final CampaignMember? _mockMember;

  FakeCampaignsNotifier(this._initialState, this._mockMember);

  @override
  CampaignsState build() {
    return _initialState;
  }

  @override
  Future<CampaignMember?> checkMembership(String campaignId) async {
    return _mockMember;
  }

  @override
  Future<bool> updateActiveCharacter({
    required String campaignId,
    required String? activeCharacterId,
  }) async {
    return true;
  }
}

class FakeCharactersNotifier extends CharactersNotifier {
  final CharactersState _initialState;
  FakeCharactersNotifier(this._initialState);
  @override
  CharactersState build() => _initialState;
}

void main() {
  late MockTablesDB mockTablesDb;

  final authUser = models.User.fromMap({
    '\$id': 'user_123',
    '\$createdAt': '',
    '\$updatedAt': '',
    'name': 'Grog',
    'email': 'grog@vox.com',
    'phone': '',
    'status': true,
    'labels': <String>[],
    'passwordUpdate': '',
    'emailVerification': true,
    'phoneVerification': false,
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

  final campaign = Campaign(
    id: 'camp_123',
    hexId: 'abc12345',
    name: 'Lost Mine of Phandelver',
    gmUserId: 'gm_456',
    status: 'active',
    createdAt: DateTime.now(),
  );

  final mockCharacter = Character(
    id: 'char_789',
    userId: 'user_123',
    name: 'Grog Strongjaw',
    hpCurrent: 120,
    hpMax: 120,
    ac: 17,
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockTablesDb = MockTablesDB();
  });

  testWidgets(
    'CampaignDashboardScreen renders correctly as Player and shows Active Character card',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final campaignsState = CampaignsState.success([
        UserCampaign(campaign: campaign, role: 'player'),
      ]);

      final charactersState = CharactersState.success([mockCharacter]);

      final member = CampaignMember(
        id: 'member_111',
        campaignId: 'camp_123',
        userId: 'user_123',
        activeCharacterId: 'char_789',
        role: 'player',
        joinedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
            campaignsProvider.overrideWith(
              () => FakeCampaignsNotifier(campaignsState, member),
            ),
            charactersProvider.overrideWith(
              () => FakeCharactersNotifier(charactersState),
            ),
          ],
          child: const MaterialApp(
            home: CampaignDashboardScreen(hexId: 'abc12345'),
          ),
        ),
      );

      await tester.pump(); // Start fetching
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lost Mine of Phandelver'), findsWidgets);
      expect(find.text('JOGADOR'), findsOneWidget);
      expect(find.text('Grog Strongjaw'), findsOneWidget);
      expect(find.text('HP Máx: 120 | CA: 17'), findsOneWidget);
      expect(
        find.byKey(const Key('change_active_char_button')),
        findsOneWidget,
      );

      // Tap share button
      await tester.tap(find.byKey(const Key('dashboard_share_button')));
      await tester.pumpAndSettle();

      expect(find.text('Compartilhar Campanha'), findsWidgets);
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );
}
