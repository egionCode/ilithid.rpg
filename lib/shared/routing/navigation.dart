/// Navigation history helpers shared by every screen.
///
/// Objective: give the Android hardware back button a predictable behaviour.
/// The app pushes screens onto the router stack, so back pops one screen at a
/// time; when the stack is empty (deep link, web reload, cold start on a
/// sub-route) each screen declares a fallback location instead of letting the
/// framework close the application. Only the root screens ask for an exit
/// confirmation.
///
/// Dependencies: go_router (stack + imperative pop), flutter/services
/// (SystemNavigator to actually leave the app on Android).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

extension AppNavigation on BuildContext {
  /// Goes back one entry in the navigation history.
  ///
  /// Falls back to [fallbackLocation] when there is nothing to pop, which
  /// happens when the screen was reached directly (deep link or browser
  /// reload) instead of being pushed from another screen.
  void backOr(String fallbackLocation) {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(fallbackLocation);
    }
  }
}

/// Wraps a screen so the system back gesture/button is routed through
/// [AppNavigation.backOr] semantics.
///
/// When [fallbackLocation] is null the screen is treated as a root screen:
/// there is nowhere left to go back to, so the user is asked to confirm before
/// the app is closed.
///
/// [canPop] is always false because the decision is taken here: either we pop
/// the router ourselves, redirect to the fallback, or ask for confirmation.
/// Routes pushed on top of the screen (dialogs, bottom sheets) keep their
/// default behaviour, since the framework only consults the topmost route.
class AppBackHandler extends StatelessWidget {
  const AppBackHandler({super.key, required this.child, this.fallbackLocation});

  /// Screen content, usually a [Scaffold].
  final Widget child;

  /// Location used when the router stack has no previous entry.
  /// Null marks a root screen and enables the exit confirmation.
  final String? fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }

        final fallback = fallbackLocation;
        if (fallback != null) {
          router.go(fallback);
          return;
        }

        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit) {
          // Closes the Android activity. No-op on web, where the browser owns
          // the history and this handler is never reached by a back gesture.
          await SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}

/// Asks the user to confirm leaving the app. Returns false when dismissed.
Future<bool> showExitConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('exit_confirmation_dialog'),
      backgroundColor: AppColors.surface,
      title: const Text(
        'Sair do ilithid?',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: const Text(
        'Você deseja fechar o aplicativo?',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          key: const Key('exit_confirmation_cancel_button'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          key: const Key('exit_confirmation_confirm_button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sair', style: TextStyle(color: AppColors.damage)),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
