import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_scaffold.dart';
import 'package:stoppr/core/streak/streak_service.dart';

class RelapseSignatureScreen extends StatefulWidget {
  final int targetDays;
  const RelapseSignatureScreen({super.key, this.targetDays = 7});

  @override
  State<RelapseSignatureScreen> createState() => _RelapseSignatureScreenState();
}

class _RelapseSignatureScreenState extends State<RelapseSignatureScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('relapse_signature_title'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height / 3.2,
                    width: double.infinity,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _SignatureCanvas(key: UniqueKey()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    // Ensure notifications plugin is initialized before scheduling
                    try {
                      await NotificationService().initialize();
                    } catch (e, st) {
                      debugPrint('RelapseSignature: Notification init failed: $e');
                      CrashlyticsService.logException(
                        e,
                        st,
                        reason: 'relapse_signature_init_notifications',
                      );
                    }
                    if (!mounted) return;

                    // Schedule daily congratulation notifications for the selected goal
                    try {
                      await NotificationService().scheduleRelapseChallengeNotifications(
                        totalDays: widget.targetDays,
                      );
                    } catch (e, st) {
                      debugPrint('RelapseSignature: scheduleRelapseChallengeNotifications error: $e');
                      CrashlyticsService.logException(
                        e,
                        st,
                        reason: 'relapse_signature_schedule_relapse',
                      );
                    }
                    if (!mounted) return;

                    // Persist a flag to show a 7-second toast on home
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('relapse_show_toast', true);
                      await prefs.setInt('relapse_goal_days', widget.targetDays);
                    } catch (e, st) {
                      debugPrint('RelapseSignature: SharedPreferences write failed: $e');
                      CrashlyticsService.logException(
                        e,
                        st,
                        reason: 'relapse_signature_prefs_write',
                      );
                    }
                    if (!mounted) return;

                    // Reset streak to 0 upon completing signature
                    try {
                      await StreakService().resetStreakCounter();
                    } catch (e) {
                      debugPrint('RelapseSignature: Failed to reset streak: $e');
                    }
                    if (!mounted) return;

                    Navigator.of(context).pushReplacement(
                      FadePageRoute(
                        child: const MainScaffold(initialIndex: 0),
                        settings: const RouteSettings(name: '/home'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: Center(
                      child: Text(
                        l10n.translate('common_continue'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureCanvas extends StatefulWidget {
  const _SignatureCanvas({super.key});

  @override
  State<_SignatureCanvas> createState() => _SignatureCanvasState();
}

class _SignatureCanvasState extends State<_SignatureCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (d) => setState(() => _current = [d.localPosition]),
            onPanUpdate: (d) => setState(() => _current.add(d.localPosition)),
            onPanEnd: (_) => setState(() {
              if (_current.isNotEmpty) {
                _strokes.add(List.from(_current));
                _current.clear();
              }
            }),
            dragStartBehavior: DragStartBehavior.down,
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: _SignaturePainter(_strokes, _current),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFF666666)),
            onPressed: () => setState(() {
              _strokes.clear();
              _current.clear();
            }),
          ),
        )
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  _SignaturePainter(this.strokes, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFed3272)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final s in strokes) {
      if (s.length > 1) {
        final path = Path()..moveTo(s[0].dx, s[0].dy);
        for (int i = 1; i < s.length; i++) {
          path.lineTo(s[i].dx, s[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (s.length == 1) {
        canvas.drawCircle(s[0], 1.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }
    }

    if (current.length > 1) {
      final path = Path()..moveTo(current[0].dx, current[0].dy);
      for (int i = 1; i < current.length; i++) {
        path.lineTo(current[i].dx, current[i].dy);
      }
      canvas.drawPath(path, paint);
    } else if (current.length == 1) {
      canvas.drawCircle(current[0], 1.5, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


