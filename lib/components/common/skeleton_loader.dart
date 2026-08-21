import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({super.key, this.width, this.height, this.borderRadius});
  final double? width;
  final double? height;
  final double? borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        width: widget.width, height: widget.height ?? 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + _animation.value, 0),
            end: Alignment(-_animation.value, 0),
            colors: [colors.surfaceVariant.withValues(alpha: 0.5), colors.surfaceVariant.withValues(alpha: 0.9), colors.surfaceVariant.withValues(alpha: 0.5)],
          ),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5});
  final int itemCount;
  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(itemCount, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SkeletonLoader(width: 40, height: 40, borderRadius: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonLoader(height: 14, borderRadius: 4),
          const SizedBox(height: 6),
          SkeletonLoader(width: 120, height: 10, borderRadius: 4),
        ])),
      ]),
    )));
  }
}
