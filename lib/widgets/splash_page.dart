import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_shell.dart';
import '../screens/splash_screen.dart';
import 'app_logo.dart';

/// Brief branded splash shown on every app launch.
/// Displays the logo for ~2 seconds, then navigates to the appropriate
/// screen (onboarding or main app).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Navigate after 2 seconds, but only once.
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted || _navigated) return;
    _navigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final complete = prefs.getBool('onboarding_complete') ?? false;
      final userName = prefs.getString('user_name') ?? '';
      if (!mounted) return;

      // Force onboarding if user_name is missing or empty,
      // regardless of the onboarding_complete flag.
      if (!complete || userName.trim().isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const AppLogo(size: 120),
        ),
      ),
    );
  }
}
