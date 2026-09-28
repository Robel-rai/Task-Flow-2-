import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nav_page.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

/// Wide card above the color-theme section that renders the app window in
/// dark and light mode side by side, using each mode's *effective* palette
/// (custom values if set, otherwise built-in defaults). Selecting a preset
/// or editing a custom color updates the matching mockup instantly.
class ThemeModePreviewCard extends StatelessWidget {
  const ThemeModePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    // The brightness actually in effect (theme mode + system fallback).
    final activeIsDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PreviewColumn(
                label: 'Dark',
                active: activeIsDark,
                colors: colors,
                child: _WindowMockup(dark: true, settings: settings),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _PreviewColumn(
                label: 'Light',
                active: !activeIsDark,
                colors: colors,
                child: _WindowMockup(dark: false, settings: settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single mockup with its label and active-mode check badge underneath.
class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.label,
    required this.active,
    required this.colors,
    required this.child,
  });

  final String label;
  final bool active;
  final AppThemeColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 10),
        SizedBox(
          height: 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: active ? colors.primary : colors.border,
                    width: 1.5,
                  ),
                ),
                child: active
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Miniature, non-interactive rendering of the app shell (title bar,
/// sidebar nav, dashboard-style content) painted with the given mode's
/// effective colors.
class _WindowMockup extends StatelessWidget {
  const _WindowMockup({required this.dark, required this.settings});

  final bool dark;
  final SettingsProvider settings;

  Color c(String role) => settings.currentRoleColor(role, dark);

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));

    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: c('bg'),
        borderRadius: radius,
        border: Border.all(color: c('border')),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            _titleBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sidebar(),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBar() {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: c('surface'),
        border: Border(bottom: BorderSide(color: c('border'))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _trafficLight(const Color(0xFFFF5F57)),
          const SizedBox(width: 4),
          _trafficLight(const Color(0xFFFEBC2E)),
          const SizedBox(width: 4),
          _trafficLight(const Color(0xFF28C840)),
          const Spacer(),
          Text(
            'Freebuff',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: c('textTertiary'),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 26), // balance the traffic lights
        ],
      ),
    );
  }

  Widget _trafficLight(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _sidebar() {
    final pages = NavPage.values.take(4).toList(); // Dashboard, Tasks, Calendar, Projects
    return Container(
      width: 86,
      color: c('sidebarBg'),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < pages.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            _navItem(
              icon: pages[i].icon,
              active: i == 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _navItem({required IconData icon, required bool active}) {
    final fg =
        active ? c('navActiveText') : c('navInactiveText').withValues(alpha: 0.85);
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: active ? c('navActive') : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 9, color: fg),
          const SizedBox(width: 5),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: fg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header: title bar + action pill
          Row(
            children: [
              _bar(48, 6, c('textPrimary')),
              const Spacer(),
              Container(
                width: 28,
                height: 11,
                decoration: BoxDecoration(
                  color: c('primary'),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Two stat cards
          Row(
            children: [
              Expanded(child: _statCard()),
              const SizedBox(width: 8),
              Expanded(child: _statCard()),
            ],
          ),
          const SizedBox(height: 8),
          // Task list card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c('surface'),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c('border')),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _listRow(checked: true),
                  _listRow(checked: false),
                  _listRow(checked: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard() {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c('surface'),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c('border')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _bar(16, 3, c('textTertiary')),
          _bar(26, 5, c('textPrimary')),
        ],
      ),
    );
  }

  Widget _listRow({required bool checked}) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: checked ? c('primary') : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: checked ? c('primary') : c('border'),
              width: 1,
            ),
          ),
          child: checked
              ? const Icon(Icons.check, size: 5, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _bar(
            double.infinity,
            4,
            c(checked ? 'textTertiary' : 'textSecondary'),
          ),
        ),
      ],
    );
  }

  Widget _bar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
