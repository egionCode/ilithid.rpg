import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color getBgColor() {
      if (onPressed == null) return theme.disabledColor;
      switch (variant) {
        case AppButtonVariant.primary:
          return theme.colorScheme.primary;
        case AppButtonVariant.secondary:
          return theme.colorScheme.surface;
        case AppButtonVariant.danger:
          return theme.colorScheme.error;
      }
    }

    Color getFgColor() {
      if (onPressed == null) return theme.colorScheme.onSurface.withAlpha(97);
      switch (variant) {
        case AppButtonVariant.primary:
          return theme.colorScheme.onPrimary;
        case AppButtonVariant.secondary:
          return theme.colorScheme.onSurface;
        case AppButtonVariant.danger:
          return theme.colorScheme.onError;
      }
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: getBgColor(),
      foregroundColor: getFgColor(),
      side: variant == AppButtonVariant.secondary
          ? BorderSide(color: theme.dividerColor)
          : null,
    );

    final Widget buttonChild = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : child;

    final Widget button = ElevatedButton(
      style: buttonStyle,
      onPressed: isLoading ? null : onPressed,
      child: buttonChild,
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}
