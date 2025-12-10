import 'package:flutter/material.dart';
import 'dart:math' as math;

class NutrientProgressRing extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color color;
  final IconData? icon;
  final double size;
  final double strokeWidth;

  const NutrientProgressRing({
    Key? key,
    required this.value,
    required this.maxValue,
    required this.color,
    this.icon,
    this.size = 80,
    this.strokeWidth = 6,
  }) : assert(size > 0),
       assert(strokeWidth > 0),
       assert(strokeWidth < size / 2),
       assert(maxValue > 0),
       assert(value >= 0),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (maxValue <= 0)
        ? 0.0
        : (value / maxValue).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: Size(size, size),
            painter: CircularProgressPainter(
              progress: 1.0,
              color: Colors.white.withOpacity(0.1),
              strokeWidth: strokeWidth,
            ),
          ),
          // Progress circle
          CustomPaint(
            size: Size(size, size),
            painter: CircularProgressPainter(
              progress: percentage,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          // Center icon
          if (icon != null)
            Icon(
              icon,
              color: color,
              size: size * 0.35,
            ),
        ],
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Start from top (-90 degrees)
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
