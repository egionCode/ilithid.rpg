/// Tests for the back navigation history rules implemented in
/// lib/shared/routing/navigation.dart.
///
/// The Android hardware back button reaches Flutter as a `popRoute` platform
/// message on the `flutter/navigation` channel, so that is what these tests
/// send to reproduce a real back press.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/shared/routing/navigation.dart';

/// Simulates the Android hardware back button.
Future<void> pressSystemBack(WidgetTester tester) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    const MethodCall('popRoute'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

Widget _screen({
  required String title,
  String? fallbackLocation,
  VoidCallback? onNext,
}) {
  return AppBackHandler(
    fallbackLocation: fallbackLocation,
    child: Scaffold(
      body: Column(
        children: [
          Text(title),
          if (onNext != null)
            ElevatedButton(onPressed: onNext, child: const Text('next')),
        ],
      ),
    ),
  );
}

GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            _screen(title: 'home', onNext: () => context.push('/details')),
      ),
      GoRoute(
        path: '/details',
        builder: (context, state) =>
            _screen(title: 'details', fallbackLocation: '/'),
      ),
    ],
  );
}

void main() {
  testWidgets('system back pops to the previous screen', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.text('details'), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.text('home'), findsOneWidget);
    expect(find.text('details'), findsNothing);
  });

  testWidgets('system back closes an open dialog before leaving the screen', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('home'));
    unawaitedDialog(context);
    await tester.pumpAndSettle();
    expect(find.text('dialog content'), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.text('dialog content'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('system back falls back to the parent when there is no history', (
    tester,
  ) async {
    // Entering directly through a deep link leaves an empty stack.
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: buildRouter(initialLocation: '/details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('details'), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('system back on the root screen asks to confirm the exit', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    await pressSystemBack(tester);
    expect(find.byKey(const Key('exit_confirmation_dialog')), findsOneWidget);

    // Cancelling keeps the user inside the app.
    await tester.tap(find.byKey(const Key('exit_confirmation_cancel_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exit_confirmation_dialog')), findsNothing);
    expect(
      platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
      isEmpty,
    );

    // Confirming closes the application.
    await pressSystemBack(tester);
    await tester.tap(find.byKey(const Key('exit_confirmation_confirm_button')));
    await tester.pumpAndSettle();
    expect(
      platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
      isNotEmpty,
    );
  });
}

/// Opens a plain dialog on top of the current screen.
void unawaitedDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const AlertDialog(content: Text('dialog content')),
  );
}
