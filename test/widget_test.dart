// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/main.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.unauthenticated();
  }

  @override
  Future<void> checkSession() async {
    // No-op for smoke test
  }
}

void main() {
  testWidgets('Smoke test: Verify login screen loaded on start by default', (
    tester,
  ) async {
    // Build our app and trigger a frame, overriding authProvider to isolate UI from real Appwrite client.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => FakeAuthNotifier())],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that our login screen header is displayed.
    expect(find.text('Login to your RPG Helper account'), findsOneWidget);
  });
}
