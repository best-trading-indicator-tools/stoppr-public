import 'dart:math';
import 'package:flutter/material.dart';

class FastingProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final Widget? center;
  final int targetMinutes;

  const FastingProgressRing({
    super.key,
    required this.progress,
    this.size = 260,
    this.center,
    this.targetMinutes = 960, // default 16h
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect behind ring
          CustomPaint(
            size: Size(size, size),
            painter: _GlowPainter(progress: progress),
          ),
          // Main ring with milestones
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              targetMinutes: targetMinutes,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

// Glow effect painter
class _GlowPainter extends CustomPainter {
  final double progress;
  _GlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFed3272).withOpacity(0.15),
          const Color(0xFFfd5d32).withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 20))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    final sweep = (progress.clamp(0.0, 1.0)) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final int targetMinutes;
  
  _RingPainter({required this.progress, required this.targetMinutes});

  // Milestone definitions (in minutes)
  static final List<int> milestoneMinutes = [12 * 60, 16 * 60, 18 * 60, 24 * 60, 36 * 60];
  static final List<Color> milestoneColors = [
    const Color(0xFF4CAF50), // 12h - green
    const Color(0xFFed3272), // 16h - pink
    const Color(0xFFFF9800), // 18h - orange
    const Color(0xFF9C27B0), // 24h - purple
    const Color(0xFFFFD700), // 36h - gold
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    // Background track with subtle inner shadow effect
    final track = Paint()
      ..color = const Color(0xFFEFF1F5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 16;

    // Draw background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      track,
    );

    // Draw progress arc only if there's actual progress
    final sweep = (progress.clamp(0.0, 1.0)) * 2 * pi;
    if (sweep > 0.001) { // Minimum threshold to avoid gradient assertion
      // Progress with enhanced gradient
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: -pi / 2 + sweep,
          colors: const [
            Color(0xFFed3272),
            Color(0xFFfd5d32),
            Color(0xFFed3272),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweep,
        false,
        progressPaint,
      );
    }

    // Draw milestone markers
    for (int i = 0; i < milestoneMinutes.length; i++) {
      final milestoneMin = milestoneMinutes[i];
      if (milestoneMin > targetMinutes) continue; // Don't show if beyond target
      
      final milestoneProgress = milestoneMin / targetMinutes;
      final angle = -pi / 2 + (milestoneProgress * 2 * pi);
      final markerX = center.dx + radius * cos(angle);
      final markerY = center.dy + radius * sin(angle);
      final markerCenter = Offset(markerX, markerY);
      
      final isPassed = progress >= milestoneProgress;
      
      // Outer glow for passed milestones
      if (isPassed) {
        final glowPaint = Paint()
          ..color = milestoneColors[i].withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(markerCenter, 8, glowPaint);
      }
      
      // Marker dot
      final markerPaint = Paint()
        ..color = isPassed ? milestoneColors[i] : Colors.white
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = isPassed ? milestoneColors[i] : const Color(0xFFE0E0E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(markerCenter, isPassed ? 6 : 5, markerPaint);
      canvas.drawCircle(markerCenter, isPassed ? 6 : 5, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.targetMinutes != targetMinutes;
}


