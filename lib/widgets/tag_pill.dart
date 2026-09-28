import 'package:flutter/material.dart';

import '../models/tag.dart';
import '../theme/app_colors.dart';

/// A pill-shaped tag chip used wherever tags are displayed.
///
/// Visuals are color-free by design: an unselected pill is neutral, while a
/// pill assigned to the task ([selected] = true) is outlined in the theme's
/// primary color with a faint primary-tinted fill, so the active state is
/// obvious at a glance and follows any custom accent color.
///
/// [onDelete], when provided, shows a small ✕ inside the pill's trailing
/// edge that removes the tag after confirmation by the caller.
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.tag,
    this.selected = false,
    this.onToggle,
    this.onDelete,
    this.deleteTooltip = 'Delete tag',
  });

  final Tag tag;
  final bool selected;

  /// Called when the pill body is tapped (e.g. toggle selection).
  /// When null the pill is not interactive.
  final VoidCallback? onToggle;

  /// Called when the ✕ is tapped. Omit to hide the delete affordance.
  final VoidCallback? onDelete;

  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final outline =
        selected ? colors.primary : colors.border;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : colors.surfaceVariant.withValues(alpha: 0.6),
      shape: StadiumBorder(
        side: BorderSide(
          color: outline,
          width: selected ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 6, onDelete == null ? 12 : 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tag.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 2),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    tooltip: deleteTooltip,
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close,
                        size: 14, color: colors.textSecondary),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
