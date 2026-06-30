import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/auth/presentation/screens/server_config_screen.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

class AppRouter {
  static const String home = '/';
  static const String config = '/config';

  static final GoRouter router = GoRouter(
    initialLocation: config, // Always start with config to ensure server connection
    routes: [
      GoRoute(
        path: config,
        builder: (context, state) => ServerConfigScreen(
          onConfigSaved: () {
            context.go(home);
          },
        ),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ilithid RPG Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.go(AppRouter.config);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to ilithid!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await client.ping();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ping successful!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ping failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Send a ping'),
            ),
          ],
        ),
      ),
    );
  }
}
