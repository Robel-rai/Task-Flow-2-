import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Theme-aware app logo:
/// - **Dark mode** → shows the light-colored logo (for contrast on dark bg)
/// - **Light mode** → shows the dark-colored logo (for contrast on light bg)
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  /// Returns the asset path for the current brightness.
  static String _logoPath(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // In dark mode, use the light logo (light-on-dark).
    // In light mode, use the dark logo (dark-on-light).
    return brightness == Brightness.dark
        ? 'assets/icon/light_logo.svg'
        : 'assets/icon/dark_logo.svg';
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _logoPath(context),
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
