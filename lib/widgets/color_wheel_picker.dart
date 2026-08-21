import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A circular HSV color picker: hue is the angle around the wheel,
/// saturation is the distance from the center, and brightness is set
/// with the slider underneath. The current color is shown as a preview
/// swatch with its hex code.
class ColorWheel extends StatefulWidget {
  const ColorWheel({
    super.key,
    required this.color,
    required this.onChanged,
    this.size = 180,
  });

  /// The currently selected color (normalized to HSV internally).
  final Color color;

  /// Called whenever the user picks a new color via the wheel or the
  /// brightness slider.
  final ValueChanged<Color> onChanged;

  /// Diameter of the wheel in logical pixels.
  final double size;

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(ColorWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync only when the incoming color differs from what we already
    // resolved to (e.g. a preset swatch was tapped), so a drag in progress
    // is not clobbered by our own onChanged round-trip.
    if (widget.color.toARGB32() != oldWidget.color.toARGB32() &&
        _hsv.toColor().toARGB32() != widget.color.toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _updateFromPosition(Offset local) {
    final radius = widget.size / 2;
    final center = Offset(radius, radius);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy).clamp(0.0, radius);
    final saturation = dist / radius;
    var hue = math.atan2(dy, dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    setState(() {
      _hsv = HSVColor.fromAHSV(1, hue, saturation, _hsv.value);
    });
    widget.onChanged(_hsv.toColor());
  }

  void _setValue(double value) {
    setState(() {
      _hsv = HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, value);
    });
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final radius = widget.size / 2;
    final radians = _hsv.hue * math.pi / 180;
    final selector = Offset(radius, radius) +
        Offset(math.cos(radians), math.sin(radians)) *
            (_hsv.saturation * radius);
    final current = _hsv.toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanDown: (d) => _updateFromPosition(d.localPosition),
          onPanStart: (d) => _updateFromPosition(d.localPosition),
          onPanUpdate: (d) => _updateFromPosition(d.localPosition),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _WheelPainter(value: _hsv.value, selector: selector),
          ),
        ),
        Row(
          children: [
            Icon(Icons.brightness_6_outlined,
                size: 16, color: colors.textSecondary),
            Expanded(
              child: Slider(
                value: _hsv.value,
                onChanged: _setValue,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: current,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppTheme.colorToHex(current),
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.value, required this.selector});

  /// Brightness (HSV value), 0..1.
  final double value;

  /// Position of the selection ring in the painter's coordinate space.
  final Offset selector;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final wheelRect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: radius);

    // Hue by angle around the wheel.
    final sweep = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
        stops: [0.0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1.0],
      ).createShader(wheelRect);

    // Saturation: white at the center fading to the pure hue at the rim.
    final radial = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Colors.transparent],
        stops: [0.0, 1.0],
      ).createShader(wheelRect);

    canvas.save();
    canvas.clipPath(Path()..addOval(wheelRect));
    canvas.saveLayer(wheelRect, Paint());
    canvas.drawRect(wheelRect, sweep);
    canvas.drawRect(wheelRect, radial);
    if (value < 1.0) {
      // Brightness: multiply the accumulated wheel by a gray of [value].
      final v = (value * 255).round();
      canvas.drawRect(
        wheelRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..color = Color.fromARGB(255, v, v, v),
      );
    }
    canvas.restore();
    canvas.restore();

    // Selection ring (drawn on top, not clipped): black outline + white
    // inner ring so it reads against any hue.
    canvas.drawCircle(
        selector,
        9.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xAA000000));
    canvas.drawCircle(
        selector,
        9.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.selector != selector;
}
