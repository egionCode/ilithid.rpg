import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/auth/presentation/screens/login_screen.dart';
import 'package:ilithid/features/auth/presentation/screens/register_screen.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_state.dart';
import 'package:ilithid/features/campaigns/presentation/screens/create_campaign_screen.dart';
import 'package:ilithid/features/campaigns/presentation/screens/join_campaign_screen.dart';
import 'package:ilithid/features/characters/presentation/screens/character_form_screen.dart';
import 'package:ilithid/features/characters/presentation/screens/characters_list_screen.dart';
import 'package:ilithid/features/dashboard/presentation/screens/campaign_dashboard_screen.dart';
import 'package:ilithid/features/npcs/presentation/screens/npc_form_screen.dart';
import 'package:ilithid/features/npcs/presentation/screens/npcs_library_screen.dart';
import 'package:ilithid/features/sessions/presentation/screens/session_dashboard_screen.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/state/pending_deep_link_provider.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ChangeNotifier();

  ref.listen<AuthState>(authProvider, (previous, next) {
    // Notify GoRouter to evaluate redirect rules when auth state changes
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    refreshListenable.notifyListeners();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read<AuthState>(authProvider);
      final status = authState.status;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isLoading = state.matchedLocation == '/loading';

      final isDeepLink = state.matchedLocation.startsWith('/join/');

      // Store pending deep link when unauthenticated
      if (status == AuthStatus.unauthenticated && isDeepLink) {
        ref.read(pendingDeepLinkProvider.notifier).set(state.matchedLocation);
        return '/login';
      }

      // After successful login, navigate to pending deep link if any
      if (status == AuthStatus.authenticated) {
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null) {
          ref.read(pendingDeepLinkProvider.notifier).set(null);
          return pending;
        }
        // Existing auth redirects
        if (isLoggingIn || isRegistering || isLoading) return '/';
        return null;
      }

      // Still resolving the session — show a neutral loading screen.
      if (status == AuthStatus.initial) {
        return isLoading ? null : '/loading';
      }

      if (status == AuthStatus.unauthenticated) {
        if (isLoggingIn || isRegistering) return null;
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/characters',
        builder: (context, state) => const CharactersListScreen(),
      ),
      GoRoute(
        path: '/characters/new',
        builder: (context, state) => const CharacterFormScreen(),
      ),
      GoRoute(
        path: '/characters/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return CharacterFormScreen(characterId: id);
        },
      ),
      GoRoute(
        path: '/npcs',
        builder: (context, state) => const NpcsLibraryScreen(),
      ),
      GoRoute(
        path: '/npcs/new',
        builder: (context, state) => const NpcFormScreen(),
      ),
      GoRoute(
        path: '/campaigns/new',
        builder: (context, state) => const CreateCampaignScreen(),
      ),
      // IMPORTANT: specific routes must come before the generic :hexId route
      GoRoute(
        path: '/campaigns/join',
        builder: (context, state) => const JoinCampaignScreen(),
      ),
      GoRoute(
        path: '/campaigns/join/:hexId',
        builder: (context, state) {
          final hexId = state.pathParameters['hexId'];
          return JoinCampaignScreen(initialHexId: hexId);
        },
      ),
      GoRoute(
        path: '/campaigns/:hexId/session/:sessionId',
        builder: (context, state) {
          final hexId = state.pathParameters['hexId'] ?? '';
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return SessionDashboardScreen(hexId: hexId, sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/campaigns/:hexId',
        builder: (context, state) {
          final hexId = state.pathParameters['hexId'] ?? '';
          return CampaignDashboardScreen(hexId: hexId);
        },
      ),
    ],
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch<AuthState>(authProvider);
    final campaignsState = ref.watch(campaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ilithid'),
        actions: [
          IconButton(
            key: const Key('home_characters_button'),
            icon: const Icon(Icons.shield_outlined, color: AppColors.primary),
            tooltip: 'Minhas Fichas',
            onPressed: () => context.go('/characters'),
          ),
          IconButton(
            key: const Key('home_npcs_button'),
            icon: const Icon(
              Icons.auto_stories_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Biblioteca de NPCs',
            onPressed: () => context.go('/npcs'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.damage),
            onPressed: () {
              ref.read<AuthNotifier>(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.go('/campaigns/new'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nova Campanha',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(campaignsProvider.notifier).fetchCampaigns();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Greeting Info Card
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(51),
                      radius: 24,
                      child: Text(
                        (authState.displayName ?? 'P')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, ${authState.displayName ?? 'Player'}!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authState.user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Minhas Campanhas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('home_join_campaign_button'),
                    onPressed: () => context.go('/campaigns/join'),
                    icon: const Icon(
                      Icons.login,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    label: const Text(
                      'Entrar',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Error message if any
              if (campaignsState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.damage.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.damage.withAlpha(77)),
                  ),
                  child: Text(
                    campaignsState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.damage),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Loading state when list is empty
              if (campaignsState.status == CampaignsStatus.loading &&
                  campaignsState.campaigns.isEmpty) ...[
                const SizedBox(height: 48),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ]
              // Empty state
              else if (campaignsState.campaigns.isEmpty) ...[
                const SizedBox(height: 24),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.sports_esports_outlined,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhuma campanha encontrada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crie uma nova campanha como Mestre ou entre em uma existente usando o código.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppButton(
                              onPressed: () => context.go('/campaigns/new'),
                              child: const Text('Criar Campanha'),
                            ),
                            const SizedBox(width: 12),
                            AppButton(
                              key: const Key(
                                'empty_state_join_campaign_button',
                              ),
                              onPressed: () => context.go('/campaigns/join'),
                              variant: AppButtonVariant.secondary,
                              child: const Text('Entrar em Campanha'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ]
              // List state
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: campaignsState.campaigns.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final userCampaign = campaignsState.campaigns[index];
                    final campaign = userCampaign.campaign;
                    final isGm = userCampaign.role == 'gm';

                    return InkWell(
                      onTap: () => context.go('/campaigns/${campaign.hexId}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // Campaign Icon Indicator
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isGm
                                    ? AppColors.masterMagic.withAlpha(26)
                                    : AppColors.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isGm
                                    ? Icons.gavel_rounded
                                    : Icons.person_rounded,
                                color: isGm
                                    ? AppColors.masterMagic
                                    : AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Campaign Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    campaign.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Código: ${campaign.hexId.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Badges/Chips
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isGm
                                        ? AppColors.masterMagic.withAlpha(38)
                                        : AppColors.border,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isGm
                                          ? AppColors.masterMagic.withAlpha(77)
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    isGm ? 'MESTRE' : 'JOGADOR',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isGm
                                          ? AppColors.masterMagic
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Status Badge
                                Text(
                                  campaign.status == 'active'
                                      ? 'Ativa'
                                      : 'Finalizada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: campaign.status == 'active'
                                        ? AppColors.heal
                                        : AppColors.damage,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 80), // Extra space to scroll above FAB
            ],
          ),
        ),
      ),
    );
  }
}

/// Displayed while [AuthNotifier.checkSession] resolves on startup.
/// The router redirects here automatically when [AuthStatus] is [AuthStatus.initial]
/// and navigates away as soon as the status transitions.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ilithid',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
