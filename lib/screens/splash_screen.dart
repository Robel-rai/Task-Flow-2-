import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

/// Multi-page intro splash shown on first launch (and when re-triggered
/// from Settings).  Describes what TaskFlow is about before handing
/// off to the [OnboardingScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Clears the onboarding flag so the splash re-appears on next launch.
  static Future<void> resetFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', false);
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = _SplashPageData.list;

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    // Mark onboarding as complete so next launch goes straight to the app.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SplashPage(data: _pages[i]),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
              child: Row(
                children: [
                  // Page indicators
                  Row(
                    children: [
                      for (int i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppTheme.primary
                                : colors.textTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Next / Get Started button
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _page == _pages.length - 1 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single splash page.
class _SplashPage extends StatelessWidget {
  const _SplashPage({required this.data});
  final _SplashPageData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 64, color: data.color),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashPageData {
  const _SplashPageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  static const list = [
    _SplashPageData(
      icon: Icons.check_circle_outline,
      color: AppTheme.primary,
      title: 'Welcome to TaskFlow',
      subtitle:
          'The modern task manager built for focus.\nOrganize your work, track your habits,\nand see your productivity soar.',
    ),
    _SplashPageData(
      icon: Icons.dashboard_outlined,
      color: AppTheme.emerald,
      title: 'Smart Dashboard',
      subtitle:
          'Your daily command center at a glance.\nKPIs, charts, today\'s agenda, and\nquick-add — all in one place.',
    ),
    _SplashPageData(
      icon: Icons.calendar_today,
      color: AppTheme.blue,
      title: 'Calendar & Scheduling',
      subtitle:
          'Drag-and-drop rescheduling,\nmonth / week / day / agenda views,\nand recurring tasks on autopilot.',
    ),
    _SplashPageData(
      icon: Icons.timer_outlined,
      color: AppTheme.indigo,
      title: 'Focus Timer & Routines',
      subtitle:
          'Pomodoro-style focus sessions with\nbreak reminders. Build daily habits\nwith streaks and routine tracking.',
    ),
    _SplashPageData(
      icon: Icons.folder_outlined,
      color: AppTheme.purple,
      title: 'Projects & Kanban',
      subtitle:
          'Group tasks into projects and\ntrack progress on a kanban board.\nDrag cards to update status.',
    ),
    _SplashPageData(
      icon: Icons.bar_chart,
      color: AppTheme.sky,
      title: 'Analytics & Insights',
      subtitle:
          'Productivity scores, streaks, focus\ncharts, and weekly reports.\nExport to CSV anytime.',
    ),
  ];
}
