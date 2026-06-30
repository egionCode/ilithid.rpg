import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

class AppRouter {
  static const String home = '/';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(path: home, builder: (context, state) => const HomeScreen()),
    ],
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ilithid RPG Helper')),
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Ping failed: $e')));
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
