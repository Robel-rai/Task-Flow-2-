import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Temporary body shown by every screen until Phase 3+ ships the real UI.
class PlaceholderContent extends StatelessWidget {
  const PlaceholderContent({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Column(
      children: [
        // Header bar (matches the pattern real screens will use).
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              if (AppTheme.isScreenCollapsed(context)) ...[
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 56,
                    color: colors.textTertiary.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  '$title — coming in Phase 3+',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
