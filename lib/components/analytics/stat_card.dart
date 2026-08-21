import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Animated KPI card matching the dashboard style: icon top-left,
/// large animated value, label below. Uses [LayoutBuilder] for
/// responsive row-to-wrap transitions.
class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.targetValue,
    required this.icon,
    this.color,
    this.formatter,
    this.height,
  });

  final String label;
  final double targetValue;
  final IconData icon;
  final Color? color;

  /// Optional custom formatter. Defaults to rounding to int.
  final String Function(double value)? formatter;

  /// Fixed height for the card. When null, the card sizes to its content.
  final double? height;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  String _format(double v) {
    if (widget.formatter != null) return widget.formatter!(v);
    return '${v.round()}';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: widget.targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant StatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      _animation = Tween<double>(
        begin: 0,
        end: widget.targetValue,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final accent = widget.color ?? colors.textSecondary;

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Text(
              _format(_animation.value),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: cardContent);
    }
    return cardContent;
  }
}

/// Responsive wrapper that lays out [StatCard]s in a fluid [Wrap]
/// with uniform card heights. Columns adjust automatically:
///
/// - ≥900px: 3 columns
/// - 600–899px: 2 columns
/// - <600px: 1 column
///
/// Each card gets a fixed height of [cardHeight] so rows are always
/// uniform regardless of label length.
class StatCardRow extends StatelessWidget {
  const StatCardRow({
    super.key,
    required this.cards,
    this.cardHeight = 140,
  });

  final List<Widget> cards;

  /// Fixed height applied to every card for uniform appearance.
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const spacing = 12.0;

        // Determine column count based on available width
        final cols = w >= 900 ? 3 : w >= 600 ? 2 : 1;
        final cardW = (w - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardW,
                height: cardHeight,
                child: card,
              ),
          ],
        );
      },
    );
  }
}

/// Formats large numbers for display: 9999 → "9999", 10000 → "10k+".
String formatCompactNumber(double value) {
  final n = value.round();
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M+';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k+';
  return '$n';
}

/// Compact stat card with horizontal layout: icon on the left,
/// value + label stacked on the right. Designed for dense overview rows.
class CompactStatCard extends StatefulWidget {
  const CompactStatCard({
    super.key,
    required this.label,
    required this.targetValue,
    required this.icon,
    this.color,
    this.formatter,
  });

  final String label;
  final double targetValue;
  final IconData icon;
  final Color? color;
  final String Function(double value)? formatter;

  @override
  State<CompactStatCard> createState() => _CompactStatCardState();
}

class _CompactStatCardState extends State<CompactStatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  String _format(double v) {
    if (widget.formatter != null) return widget.formatter!(v);
    return formatCompactNumber(v);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: widget.targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CompactStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      _animation = Tween<double>(
        begin: 0,
        end: widget.targetValue,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final accent = widget.color ?? colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 15, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => Text(
                    _format(_animation.value),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.label,
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive wrapper for [CompactStatCard]s.
///
/// Uses a fluid [Wrap] with adaptive columns:
/// - ≥900px: 6 columns
/// - 600–899px: 3 columns
/// - <600px: 2 columns
///
/// Each card gets a fixed height of [cardHeight].
class CompactStatCardRow extends StatelessWidget {
  const CompactStatCardRow({
    super.key,
    required this.cards,
    this.cardHeight = 56,
  });

  final List<Widget> cards;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const spacing = 8.0;

        final cols = w >= 900 ? 6 : w >= 600 ? 3 : 2;
        final cardW = (w - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardW,
                height: cardHeight,
                child: card,
              ),
          ],
        );
      },
    );
  }
}
