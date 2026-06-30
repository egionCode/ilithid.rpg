import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/auth/presentation/screens/login_screen.dart';
import 'package:ilithid/features/auth/presentation/screens/register_screen.dart';
import 'package:ilithid/shared/components/app_button.dart';

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

      if (status == AuthStatus.initial) {
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        if (isLoggingIn || isRegistering) return null;
        return '/login';
      }

      if (status == AuthStatus.authenticated) {
        if (isLoggingIn || isRegistering) return '/';
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ],
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch<AuthState>(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ilithid RPG Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read<AuthNotifier>(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, ${authState.displayName ?? 'Player'}!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Email: ${authState.user?.email ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              AppButton(
                onPressed: () {
                  ref.read<AuthNotifier>(authProvider.notifier).logout();
                },
                variant: AppButtonVariant.danger,
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
