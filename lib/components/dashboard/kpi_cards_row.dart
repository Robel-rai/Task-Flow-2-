import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analytics_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// KPI stat cards driven by [AnalyticsProvider] aggregates.
class KpiCardsRow extends StatelessWidget {
  const KpiCardsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsProvider>();

    final cards = <_KpiCard>[
      _KpiCard(
        label: 'Total Tasks',
        targetValue: analytics.totalTasks.toDouble(),
        icon: Icons.task_alt,
        color: AppTheme.primary,
        formatter: (v) => '${v.round()}',
      ),
      _KpiCard(
        label: 'Completed',
        targetValue: analytics.completedTasks.toDouble(),
        icon: Icons.check_circle,
        color: AppTheme.emerald,
        formatter: (v) => '${v.round()}',
      ),
      _KpiCard(
        label: 'Pending',
        targetValue: analytics.pendingTasks.toDouble(),
        icon: Icons.pending_actions,
        color: AppTheme.amber,
        formatter: (v) => '${v.round()}',
      ),
      _KpiCard(
        label: 'Hours Logged',
        targetValue: analytics.hoursLogged,
        icon: Icons.timer_outlined,
        color: AppTheme.blue,
        formatter: (v) => v.toStringAsFixed(1),
      ),
      _KpiCard(
        label: 'Efficiency',
        targetValue: analytics.efficiencyRate,
        icon: Icons.speed,
        color: AppTheme.purple,
        formatter: (v) => '${v.round()}%',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final card in cards)
                SizedBox(
                  width: (constraints.maxWidth - 24) / 2,
                  child: card,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.label,
    required this.targetValue,
    required this.icon,
    required this.color,
    required this.formatter,
  });

  final String label;
  final double targetValue;
  final IconData icon;
  final Color color;
  final String Function(double) formatter;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

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
  void didUpdateWidget(covariant _KpiCard oldWidget) {
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
    return Container(
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
              color: widget.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Text(
              widget.formatter(_animation.value),
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
          ),
        ],
      ),
    );
  }
}
