import 'package:flutter/material.dart';
import 'package:ilithid/shared/utils/breakpoints.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        DeviceType deviceType = DeviceType.desktop;
        
        if (width < Breakpoints.mobileMax) {
          deviceType = DeviceType.mobile;
        } else if (width <= Breakpoints.tabletMax) {
          deviceType = DeviceType.tablet;
        }

        return builder(context, deviceType);
      },
    );
  }
}
