import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nav_page.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

/// The "Sidebar order" sub-setting: drag the page rows to rearrange the
/// sidebar buttons. Changes apply live (the sidebar is visible alongside)
/// and persist across restarts.
class NavOrderPage extends StatelessWidget {
  const NavOrderPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();
    final pages = settings.navOrder;

    return Column(
      children: [
        // Header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to settings',
                icon: Icon(Icons.arrow_back, color: colors.textSecondary),
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Sidebar order',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Drag to rearrange the sidebar buttons. '
                      'The order is saved automatically.',
                      style: TextStyle(
                          fontSize: 12, color: colors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: settings.resetNavOrder,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset to default'),
              ),
            ],
          ),
        ),

        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.all(32),
            itemCount: pages.length,
            onReorder: settings.reorderNav,
            itemBuilder: (context, index) {
              final page = pages[index];
              return Padding(
                key: ValueKey(page.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _NavOrderRow(index: index, page: page),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NavOrderRow extends StatelessWidget {
  const _NavOrderRow({required this.index, required this.page});

  final int index;
  final NavPage page;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Drag handle (mouse-draggable on desktop).
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.drag_indicator,
                      size: 20, color: colors.textTertiary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(page.icon, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                page.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
