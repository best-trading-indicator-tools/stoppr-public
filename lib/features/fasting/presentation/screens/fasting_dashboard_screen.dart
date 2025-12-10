import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/core/services/in_app_review_service.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import '../../data/models/fast_log.dart';
import '../../data/repositories/fasting_repository.dart';
import '../widgets/fasting_progress_ring.dart';
import 'fasting_info_screen.dart';
import 'fasting_setup_screen.dart';

// Milestone definition
class FastingMilestone {
  final int minutes;
  final String titleKey;
  final String benefitKey;
  final IconData icon;
  final Color color;

  const FastingMilestone({
    required this.minutes,
    required this.titleKey,
    required this.benefitKey,
    required this.icon,
    required this.color,
  });

  static final List<FastingMilestone> all = [
    const FastingMilestone(
      minutes: 12 * 60, // 12h
      titleKey: 'fasting_milestone_12h_title',
      benefitKey: 'fasting_milestone_12h_benefit',
      icon: Icons.water_drop,
      color: Color(0xFF4CAF50),
    ),
    const FastingMilestone(
      minutes: 16 * 60, // 16h
      titleKey: 'fasting_milestone_16h_title',
      benefitKey: 'fasting_milestone_16h_benefit',
      icon: Icons.auto_awesome,
      color: Color(0xFFed3272),
    ),
    const FastingMilestone(
      minutes: 18 * 60, // 18h
      titleKey: 'fasting_milestone_18h_title',
      benefitKey: 'fasting_milestone_18h_benefit',
      icon: Icons.trending_up,
      color: Color(0xFFFF9800),
    ),
    const FastingMilestone(
      minutes: 24 * 60, // 24h
      titleKey: 'fasting_milestone_24h_title',
      benefitKey: 'fasting_milestone_24h_benefit',
      icon: Icons.stars,
      color: Color(0xFF9C27B0),
    ),
    const FastingMilestone(
      minutes: 36 * 60, // 36h
      titleKey: 'fasting_milestone_36h_title',
      benefitKey: 'fasting_milestone_36h_benefit',
      icon: Icons.emoji_events,
      color: Color(0xFFFFD700),
    ),
  ];
}

class FastingDashboardScreen extends StatefulWidget {
  const FastingDashboardScreen({super.key});

  @override
  State<FastingDashboardScreen> createState() => _FastingDashboardScreenState();
}

class _FastingDashboardScreenState extends State<FastingDashboardScreen> {
  final _repo = FastingRepository();
  final InAppReviewService _reviewService = InAppReviewService();
  final ScrollController _scrollController = ScrollController();
  FastLog? _active;
  Timer? _ticker;
  bool _autoEnding = false;
  int? _lastCompletedElapsedSeconds;
  OverlayEntry? _congratsEntry;
  Timer? _congratsTimer;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _ticker?.cancel();
    _congratsTimer?.cancel();
    _congratsEntry?..remove();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    
    // Hide if content doesn't need scrolling OR if at bottom
    final shouldHide = maxScroll <= 0 || currentScroll >= (maxScroll - 20);
    
    if (_showScrollIndicator != !shouldHide) {
      setState(() => _showScrollIndicator = !shouldHide);
    }
  }
  
  void _checkScrollable() {
    // Check after build if content is scrollable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _onScroll();
      }
    });
  }

  Future<void> _load() async {
    final a = await _repo.getActiveFast();
    final hadActive = _active != null;
    final willHaveActive = a != null;
    
    if (mounted) {
      setState(() => _active = a);
      _ticker?.cancel();
      if (a != null) {
        // If transitioning from no fast to active fast, scroll to top smoothly
        if (!hadActive && willHaveActive && _scrollController.hasClients) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
        
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          // Auto-end when target reached
          final int elapsed = DateTime.now()
              .difference(a.startAt)
              .inSeconds;
          if (!_autoEnding && elapsed >= a.targetMinutes * 60) {
            _autoEnding = true;
            _onEndFast();
            return;
          }
          // pull fresh elapsed without extra reads
          setState(() {});
        });
      } else {
        // ensure UI updates when becoming idle
        setState(() {});
        _autoEnding = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkScrollable();
    final l10n = AppLocalizations.of(context)!;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final active = _active;
    final bool showCongrats = false; // no longer shown inside the ring
    // Compute live seconds to ensure smooth second-by-second updates without extra reads
    final int elapsedSeconds = active == null
        ? (showCongrats ? _lastCompletedElapsedSeconds! : 0)
        : DateTime.now().difference(active.startAt).inSeconds.clamp(0, active.targetMinutes * 60);
    final double progress = active == null
        ? (showCongrats ? 1.0 : 0.0)
        : (elapsedSeconds / (active.targetMinutes * 60)).clamp(0.0, 1.0);
    final bool isFinished = active != null && elapsedSeconds >= active.targetMinutes * 60;
    final int percent = (progress * 100).clamp(0, 999).toInt();
    final String elapsed = _formatElapsedSeconds(elapsedSeconds);
    final startStr = _fmtDateTime(active?.startAt, l10n);
    final eta = active == null
        ? null
        : active.startAt.add(Duration(minutes: active.targetMinutes));
    final etaStr = _fmtDateTime(eta, l10n);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        leading: IconButton(
          onPressed: _goBackHome,
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
        ),
        title: Text(
          l10n.translate('fasting_title'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.translate('fasting_info_title'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FastingInfoScreen(),
                  settings: const RouteSettings(name: '/fasting_info'),
                ),
              );
            },
            icon: const Icon(Icons.info_outline, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                FastingProgressRing(
                  progress: progress,
                  size: 280,
                  targetMinutes: active?.targetMinutes ?? 960,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.translate('fasting_percent_elapsed').replaceAll('{percent}', percent.toString()),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        elapsed,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 44,
                          letterSpacing: -1,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (active != null) _MilestoneTimeline(active: active),
                const SizedBox(height: 16),
                _MetaRow(
                  leftLabel: l10n.translate('fasting_started_at'),
                  leftValue: startStr,
                  rightLabel: l10n.translate('fasting_estimated_end'),
                  rightValue: etaStr,
                ),
                const SizedBox(height: 12),
                // Tip should be shown above the two edit buttons when no active fast
                if (active == null)
                  Text(
                    l10n.translate('fasting_select_end_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (active == null) const SizedBox(height: 8),
                _EditRow(
                  enabled: active == null,
                  onEditStart: () async {
                    if (active == null) {
                      Navigator.of(context)
                          .push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const FastingSetupScreen(),
                          settings: const RouteSettings(name: '/fasting_setup'),
                        ),
                      )
                          .then((started) {
                        if (started == true) {
                          _load();
                          _showFastStartedToast();
                        }
                      });
                      return;
                    }
                    // Navigate to full screen setup with current elapsed time as initial values
                    final int currentElapsed = active.elapsedMinutes;
                    final int curDays = currentElapsed ~/ (24 * 60);
                    final int curHours = (currentElapsed % (24 * 60)) ~/ 60;
                    final int curMinutes = currentElapsed % 60;
                    
                    final result = await Navigator.of(context).push<({int days, int hours, int minutes})>(
                      MaterialPageRoute(
                        builder: (_) => _FastingEditStartScreen(
                          initialDays: curDays,
                          initialHours: curHours,
                          initialMinutes: curMinutes,
                        ),
                        settings: const RouteSettings(name: '/fasting_edit_start'),
                      ),
                    );
                    
                    if (result == null) return;
                    final totalMinutes = result.days*24*60 + result.hours*60 + result.minutes;
                    final newStart = DateTime.now().subtract(Duration(minutes: totalMinutes));
                    try {
                      await _repo.updateFastStart(id: active.id, newStart: newStart);
                      await _load();
                    } catch (e) {
                      debugPrint('Edit start failed: $e');
                    }
                  },
                  onEditGoal: () async {
                    if (active == null) {
                      final minutes = await _openGoalPresets(context, l10n);
                      if (minutes != null && context.mounted) {
                        Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => FastingSetupScreen(initialTargetMinutes: minutes),
                            settings: const RouteSettings(name: '/fasting_setup'),
                          ),
                        ).then((started) {
                          if (started == true) {
                            _load();
                            _showFastStartedToast();
                          }
                        });
                      }
                      return;
                    }
                    final elapsedNow = active.elapsedMinutes;
                    // Preset bottom sheet
                    Future<void> applyRemaining(int remainingMinutes) async {
                      final int minRemaining = 30;
                      final int remainingClamped = remainingMinutes < minRemaining ? minRemaining : remainingMinutes;
                      final int totalTarget = elapsedNow + remainingClamped;
                      try {
                        await _repo.updateFastTarget(id: active.id, newTargetMinutes: totalTarget);
                        await _load();
                      } catch (e) { debugPrint('Update target failed: $e'); }
                    }

                    await _openGoalPresets(context, l10n, onSelect: (m) => applyRemaining(m));
                  },
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 12),
                if (active == null)
                  _StartFastButton(
                    label: l10n.translate('fasting_start_fast'),
                    onStart: () {
                      Navigator.of(context)
                          .push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const FastingSetupScreen(),
                          settings: const RouteSettings(name: '/fasting_setup'),
                        ),
                      )
                          .then((started) {
                        if (started == true) {
                          _load();
                          _showFastStartedToast();
                        }
                      });
                    },
                  )
                else if (!isFinished)
                  _EndFastButton(onEnd: _onEndFast, label: l10n.translate('fasting_end_fast'))
                else
                  _StartFastButton(
                    label: l10n.translate('fasting_start_fast'),
                    onStart: () {
                      Navigator.of(context)
                          .push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const FastingSetupScreen(),
                          settings: const RouteSettings(name: '/fasting_setup'),
                        ),
                      )
                          .then((started) {
                        if (started == true) {
                          _load();
                          _showFastStartedToast();
                        }
                      });
                    },
                  ),
                const SizedBox(height: 24),
                _RecentFastsSection(),
                const SizedBox(height: 24),
                _StatisticsCards(),
                const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Scroll indicator at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showScrollIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFBFBFB).withOpacity(0.0),
                          const Color(0xFFFBFBFB).withOpacity(0.95),
                          const Color(0xFFFBFBFB),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const _BouncingArrow(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBackHome() {
    bool foundHome = false;
    try {
      Navigator.popUntil(context, (route) {
        if (route.settings.name == '/home' || route.settings.name == '/' || route.isFirst) {
          foundHome = true;
          return true;
        }
        return false;
      });
    } catch (_) {
      foundHome = false;
    }
    if (!foundHome && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        BottomToTopDismissPageRoute(
          child: const MainScaffold(initialIndex: 0),
          settings: const RouteSettings(name: '/home'),
        ),
        (route) => false,
      );
    }
  }


  Future<void> _onEndFast() async {
    final active = _active;
    if (active == null) return;
    // Optimistic UI: end immediately, then persist
    _ticker?.cancel();
    setState(() {
      _lastCompletedElapsedSeconds = DateTime.now().difference(active.startAt).inSeconds;
      _active = null;
    });
    _showCongratsToast();
    
    // Smoothly scroll to top after ending fast
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    
    try {
      debugPrint('FastingDashboard: End fast requested id=${active.id}');
      await NotificationService().cancelFastingEndReminder();
      await _repo.endFast(active.id, DateTime.now());
      // Trigger in-app review request at the end of a fasting exercise
      await _reviewService.requestReviewIfAppropriate(
        screenName: 'FastingDashboardScreen',
      );
    } catch (e) {
      debugPrint('End fast failed: $e');
      if (mounted) setState(() => _active = active);
    } finally {
      await _load();
      // Ensure listeners like the weekly chart refresh immediately
      _repo.emitNow();
    }
  }

  void _showCongratsToast() {
    _congratsTimer?.cancel();
    _congratsEntry?..remove();
    final entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.of(ctx).padding.top + 80;
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: _TopToastBanner(text: AppLocalizations.of(ctx)!.translate('fasting_congrats_message')),
        );
      },
    );
    Overlay.of(context)?.insert(entry);
    _congratsEntry = entry;
    _congratsTimer = Timer(const Duration(seconds: 5), () {
      _congratsEntry?..remove();
      _congratsEntry = null;
    });
  }

  void _showFastStartedToast() {
    _congratsTimer?.cancel();
    _congratsEntry?..remove();
    final entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.of(ctx).padding.top + 80;
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: _TopToastBanner(text: AppLocalizations.of(ctx)!.translate('fasting_started_toast')),
        );
      },
    );
    Overlay.of(context)?.insert(entry);
    _congratsEntry = entry;
    _congratsTimer = Timer(const Duration(seconds: 3), () {
      _congratsEntry?..remove();
      _congratsEntry = null;
    });
  }

  void _showInfo(BuildContext context) {}

  Future<int?> _openGoalPresets(BuildContext context, AppLocalizations l10n, {void Function(int minutes)? onSelect}) async {
    int? selected;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget chip(String title, String subtitle, int minutes) {
          return SizedBox(
            height: 64,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                selected = minutes;
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ).merge(ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
                overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
              )),
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFed3272), Color(0xFFfd5d32)]),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                fontFamily: 'ElzaRound',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewPadding.bottom + 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                chip(l10n.translate('fasting_goal_preset_12h_title'), l10n.translate('fasting_goal_preset_12h_subtitle'), 12 * 60),
                const SizedBox(height: 8),
                chip(l10n.translate('fasting_goal_preset_16h_title'), l10n.translate('fasting_goal_preset_16h_subtitle'), 16 * 60),
                const SizedBox(height: 8),
                chip(l10n.translate('fasting_goal_preset_18h_title'), l10n.translate('fasting_goal_preset_18h_subtitle'), 18 * 60),
                const SizedBox(height: 8),
                chip(l10n.translate('fasting_goal_preset_20h_title'), l10n.translate('fasting_goal_preset_20h_subtitle'), 20 * 60),
                const SizedBox(height: 8),
                chip(l10n.translate('fasting_goal_preset_24h_title'), l10n.translate('fasting_goal_preset_24h_subtitle'), 24 * 60),
                const SizedBox(height: 8),
                chip(l10n.translate('fasting_goal_preset_36h_title'), l10n.translate('fasting_goal_preset_36h_subtitle'), 36 * 60),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && onSelect != null) onSelect(selected!);
    return selected;
  }
}

class _EditRow extends StatelessWidget {
  final VoidCallback onEditStart;
  final VoidCallback onEditGoal;
  final bool enabled;
  const _EditRow({required this.onEditStart, required this.onEditGoal, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: enabled ? onEditStart : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              l10n.translate('fasting_edit_start'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: enabled ? const Color(0xFF1A1A1A) : const Color(0xFF1A1A1A).withOpacity(0.35)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: enabled ? onEditGoal : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              l10n.translate('fasting_edit_goal'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: enabled ? const Color(0xFF1A1A1A) : const Color(0xFF1A1A1A).withOpacity(0.35)),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekSelectorAndChart extends StatefulWidget {
  @override
  State<_WeekSelectorAndChart> createState() => _WeekSelectorAndChartState();
}

class _WeekSelectorAndChartState extends State<_WeekSelectorAndChart> {
  final _repo = FastingRepository();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final monday = _selected.subtract(Duration(days: (_selected.weekday - 1) % 7));
    final days = List<DateTime>.generate(7, (i) => monday.add(Duration(days: i)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((d) => _DayDot(date: d, selected: _isSameDay(d, _selected), onTap: (){ setState(()=>_selected=d); })).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: _MiniCompletionChart(date: _selected)),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;
}

class _FastingEditStartScreen extends StatefulWidget {
  final int initialDays;
  final int initialHours;
  final int initialMinutes;
  
  const _FastingEditStartScreen({
    required this.initialDays,
    required this.initialHours,
    required this.initialMinutes,
  });

  @override
  State<_FastingEditStartScreen> createState() => _FastingEditStartScreenState();
}

class _FastingEditStartScreenState extends State<_FastingEditStartScreen> {
  late int _days;
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
    _hours = widget.initialHours;
    _minutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          l10n.translate('fasting_edit_start'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.translate('fasting_info_title'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FastingInfoScreen(),
                  settings: const RouteSettings(name: '/fasting_info'),
                ),
              );
            },
            icon: const Icon(Icons.info_outline, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      l10n.translate('fasting_duration_hint_title'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      l10n.translate('fasting_duration_hint_units'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: _EditPickersRow(
                  days: _days,
                  hours: _hours,
                  minutes: _minutes,
                  onChanged: (d, h, m) => setState(() {
                    _days = d;
                    _hours = h;
                    _minutes = m;
                  }),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.translate('common_cancel'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, (days: _days, hours: _hours, minutes: _minutes)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ).merge(ButtonStyle(
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 0),
                      ),
                      overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
                      backgroundColor: MaterialStateProperty.all(Colors.transparent),
                    )),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                      ),
                      child: Center(
                        child: Text(
                          l10n.translate('common_save'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'ElzaRound',
                          ),
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

class _EditPickersRow extends StatelessWidget {
  final int days;
  final int hours;
  final int minutes;
  final void Function(int d, int h, int m) onChanged;
  const _EditPickersRow({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _EditWheel(
            label: l10n.translate('fasting_days'),
            min: 0,
            max: 60,
            value: days,
            onChanged: (v) => onChanged(v, hours, minutes),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _EditWheel(
            label: l10n.translate('fasting_hours'),
            min: 0,
            max: 23,
            value: hours,
            onChanged: (v) => onChanged(days, v, minutes),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _EditWheel(
            label: l10n.translate('fasting_minutes'),
            min: 0,
            max: 59,
            value: minutes,
            onChanged: (v) => onChanged(days, hours, v),
          ),
        ),
      ],
    );
  }
}

class _EditWheel extends StatelessWidget {
  final String label;
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;
  const _EditWheel({
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListWheelScrollView.useDelegate(
            controller: FixedExtentScrollController(initialItem: value),
            onSelectedItemChanged: (i) => onChanged(i),
            physics: const FixedExtentScrollPhysics(),
            itemExtent: 36,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < min || index > max) return null;
                final selected = index == value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFAE6EC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: selected ? 20 : 18,
                        color: selected ? Colors.black : Colors.grey.shade400,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  final DateTime date; final bool selected; final VoidCallback onTap;
  const _DayDot({required this.date, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final letterKeys = ['common_day_monday_letter','common_day_tuesday_letter','common_day_wednesday_letter','common_day_thursday_letter','common_day_friday_letter','common_day_saturday_letter','common_day_sunday_letter'];
    final l10n = AppLocalizations.of(context)!;
    final letter = l10n.translate(letterKeys[(date.weekday-1)%7]);
    return Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFed3272) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: selected? const Color(0xFFed3272): const Color(0xFFE0E0E0)),
              ),
              child: Center(child: Text(letter, style: TextStyle(color: selected? Colors.white: const Color(0xFF8E8E93), fontWeight: FontWeight.w700))),
            ),
            const SizedBox(height: 4),
            Text('${date.day}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }
}

class _MiniCompletionChart extends StatefulWidget {
  final DateTime? date;
  const _MiniCompletionChart({this.date});
  @override
  State<_MiniCompletionChart> createState() => _MiniCompletionChartState();
}

class _MiniCompletionChartState extends State<_MiniCompletionChart> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _repo = FastingRepository();
    final day = widget.date ?? DateTime.now();
    final monday = day.subtract(Duration(days: (day.weekday - 1) % 7));
    final days = List<DateTime>.generate(7, (i) => monday.add(Duration(days: i)));
    final l10n = AppLocalizations.of(context)!;
    final letterKeys = ['common_day_monday_letter','common_day_tuesday_letter','common_day_wednesday_letter','common_day_thursday_letter','common_day_friday_letter','common_day_saturday_letter','common_day_sunday_letter'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((d){
        final letter = l10n.translate(letterKeys[(d.weekday-1)%7]);
        return Expanded(
          child: StreamBuilder<List<FastLog>>(
            stream: _repo.watchDay(d),
            builder: (context, snap){
              final logs = snap.data ?? const <FastLog>[];
              // Prefer the active fast for the current day to match the main ring,
              // otherwise sum overlaps for completed/past logs.
              final DateTime dayStart = DateTime(d.year, d.month, d.day);
              final DateTime dayEnd = dayStart.add(const Duration(days: 1));
              int actual=0, target=0;
              // Prefer a fast that STARTED on this calendar day. In that case,
              // the breakdown should reflect the full target of that fast
              // (e.g., 16h), even if it spans into the next day.
              final List<FastLog> startedTodayList = logs
                  .where((l) =>
                      (l.startAt.isAfter(dayStart) || l.startAt.isAtSameMomentAs(dayStart)) &&
                      l.startAt.isBefore(dayEnd))
                  .toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt));
              final FastLog? startedToday =
                  startedTodayList.isNotEmpty ? startedTodayList.last : null;
              final FastLog? activeForDay = logs
                  .where((l) => l.isActive && DateTime.now().isAfter(dayStart) && DateTime.now().isBefore(dayEnd))
                  .cast<FastLog?>()
                  .fold<FastLog?>(null, (prev, e) => e ?? prev);
              // If no active fast, prefer the LAST ended fast of this day to
              // keep the percentage equal to the value at the moment you ended.
              final List<FastLog> endedTodayList = logs
                  .where((l) => l.endAt != null && l.endAt!.isAfter(dayStart) && l.endAt!.isBefore(dayEnd))
                  .toList()
                ..sort((a,b)=> a.endAt!.compareTo(b.endAt!));
              final FastLog? endedToday = endedTodayList.isNotEmpty ? endedTodayList.last : null;
              double ratio;
              if (startedToday != null) {
                final l = startedToday;
                final DateTime plannedEnd = l.startAt.add(Duration(minutes: l.targetMinutes));
                final DateTime endRef = l.endAt ?? DateTime.now();
                final DateTime cappedEnd = endRef.isAfter(plannedEnd) ? plannedEnd : endRef;
                final int elapsedSec = cappedEnd.isAfter(l.startAt)
                    ? cappedEnd.difference(l.startAt).inSeconds
                    : 0;
                final int targetSec = Duration(minutes: l.targetMinutes).inSeconds;
                ratio = targetSec > 0 ? (elapsedSec / targetSec).clamp(0.0, 1.0) : 0.0;
                actual = (elapsedSec / 60).floor();
                target = l.targetMinutes;
              } else if (activeForDay != null) {
                final l = activeForDay;
                // Compute USING per-day overlap so the value stays identical
                // before and after ending a fast.
                final int elapsedSec = _overlapSeconds(
                  startA: l.startAt,
                  endA: DateTime.now(),
                  startB: dayStart,
                  endB: dayEnd,
                );
                final int targetSec = _overlapSeconds(
                  startA: l.startAt,
                  endA: l.startAt.add(Duration(minutes: l.targetMinutes)),
                  startB: dayStart,
                  endB: dayEnd,
                );
                ratio = targetSec > 0
                    ? (elapsedSec / targetSec).clamp(0.0, 1.0)
                    : 0.0;
                // Breakdown also uses day-overlapped minutes.
                actual = (elapsedSec / 60).floor();
                target = (targetSec / 60).floor();
              } else if (endedToday != null) {
                final l = endedToday;
                final int elapsedSec = _overlapSeconds(
                  startA: l.startAt,
                  endA: l.endAt!,
                  startB: dayStart,
                  endB: dayEnd,
                );
                final int targetSec = _overlapSeconds(
                  startA: l.startAt,
                  endA: l.startAt.add(Duration(minutes: l.targetMinutes)),
                  startB: dayStart,
                  endB: dayEnd,
                );
                ratio = targetSec > 0
                    ? (elapsedSec / targetSec).clamp(0.0, 1.0)
                    : 0.0;
                actual = (elapsedSec / 60).floor();
                target = (targetSec / 60).floor();
              } else {
                int actualSecSum = 0;
                int targetSecSum = 0;
                for(final l in logs){
                  final DateTime fastStart = l.startAt;
                  final DateTime plannedEnd = fastStart.add(Duration(minutes: l.targetMinutes));
                  // Actual overlap (use seconds precision for accuracy)
                  final bool hasActual = l.endAt != null || l.isActive;
                  if (hasActual){
                    final DateTime actualEndRef = l.endAt ?? DateTime.now();
                    final int actualOverlapSec = _overlapSeconds(
                      startA: fastStart,
                      endA: actualEndRef,
                      startB: dayStart,
                      endB: dayEnd,
                    );
                    // Minutes for breakdown
                    final int actualOverlapMin = (actualOverlapSec / 60).floor();
                    actual += actualOverlapMin;
                    actualSecSum += actualOverlapSec;
                  }
                  // Target overlap (planned duration) in seconds
                  final int targetOverlapSec = _overlapSeconds(
                    startA: fastStart,
                    endA: plannedEnd,
                    startB: dayStart,
                    endB: dayEnd,
                  );
                  final int targetOverlapMin = (targetOverlapSec / 60).floor();
                  target += targetOverlapMin;
                  targetSecSum += targetOverlapSec;
                }
                ratio = targetSecSum>0? (actualSecSum/targetSecSum).clamp(0.0,1.0):0.0;
              }
              final int percent = (ratio*100).round();
              final String percentLabel = l10n.translate('fasting_chart_percent').replaceAll('{percent}', percent.toString());
              final int actualH = (actual/60).floor();
              final int targetH = (target/60).floor();
              final String breakdown = l10n
                  .translate('fasting_chart_breakdown')
                  .replaceAll('{completed}', actualH.toString())
                  .replaceAll('{total}', targetH.toString());
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Percent label
                  Text(
                    percentLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 110,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 14,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double h = constraints.maxHeight;
                              final double filled = h * ratio;
                              return Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Remaining (target minus completed)
                                  Container(
                                    height: h,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Color(0x11ed3272), Color(0x11fd5d32)],
                                      ),
                                    ),
                                  ),
                                  // Completed portion
                                  Container(
                                    height: filled,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Breakdown text
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      breakdown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(letter, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), fontWeight: FontWeight.w700)),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

int _overlapMinutes({
  required DateTime startA,
  required DateTime endA,
  required DateTime startB,
  required DateTime endB,
}) {
  final DateTime start = startA.isAfter(startB) ? startA : startB;
  final DateTime end = endA.isBefore(endB) ? endA : endB;
  if (!end.isAfter(start)) return 0;
  return end.difference(start).inMinutes;
}

int _overlapSeconds({
  required DateTime startA,
  required DateTime endA,
  required DateTime startB,
  required DateTime endB,
}) {
  final DateTime start = startA.isAfter(startB) ? startA : startB;
  final DateTime end = endA.isBefore(endB) ? endA : endB;
  if (!end.isAfter(start)) return 0;
  return end.difference(start).inSeconds;
}

class _MilestoneTimeline extends StatelessWidget {
  final FastLog active;
  const _MilestoneTimeline({required this.active});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int elapsedMinutes = active.elapsedMinutes;
    
    // Find relevant milestones within or near target
    final relevantMilestones = FastingMilestone.all
        .where((m) => m.minutes <= active.targetMinutes + 12 * 60)
        .toList();
    
    // Find current milestone (last achieved or current approaching)
    FastingMilestone? currentMilestone;
    FastingMilestone? nextMilestone;
    
    for (int i = 0; i < relevantMilestones.length; i++) {
      final milestone = relevantMilestones[i];
      if (elapsedMinutes >= milestone.minutes) {
        currentMilestone = milestone;
      } else if (nextMilestone == null) {
        nextMilestone = milestone;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show current milestone if achieved
        if (currentMilestone != null)
          _MilestoneRow(
            milestone: currentMilestone,
            status: _MilestoneStatus.achieved,
            elapsedMinutes: elapsedMinutes,
          ),
        // Show next milestone with countdown
        if (nextMilestone != null) ...[
          if (currentMilestone != null) const SizedBox(height: 12),
          _MilestoneRow(
            milestone: nextMilestone,
            status: _MilestoneStatus.upcoming,
            elapsedMinutes: elapsedMinutes,
          ),
        ],
      ],
    );
  }
}

enum _MilestoneStatus { achieved, upcoming }

class _MilestoneRow extends StatelessWidget {
  final FastingMilestone milestone;
  final _MilestoneStatus status;
  final int elapsedMinutes;
  
  const _MilestoneRow({
    required this.milestone,
    required this.status,
    required this.elapsedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isAchieved = status == _MilestoneStatus.achieved;
    
    final String title = l10n.translate(milestone.titleKey);
    final String benefit = l10n.translate(milestone.benefitKey);
    
    final int remainingMinutes = milestone.minutes - elapsedMinutes;
    final String timeText = isAchieved 
        ? l10n.translate('fasting_milestone_achieved')
        : _formatTimeRemaining(remainingMinutes, l10n);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isAchieved
            ? LinearGradient(
                colors: [
                  milestone.color.withOpacity(0.1),
                  milestone.color.withOpacity(0.05),
                ],
              )
            : null,
        color: isAchieved ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAchieved 
              ? milestone.color.withOpacity(0.3)
              : const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isAchieved
                  ? LinearGradient(
                      colors: [
                        milestone.color,
                        milestone.color.withOpacity(0.7),
                      ],
                    )
                  : null,
              color: isAchieved ? null : Colors.white,
              border: Border.all(
                color: isAchieved 
                    ? Colors.transparent
                    : const Color(0xFFE0E0E0),
                width: 2,
              ),
              boxShadow: isAchieved
                  ? [
                      BoxShadow(
                        color: milestone.color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isAchieved ? Icons.check_circle : milestone.icon,
              color: isAchieved ? Colors.white : const Color(0xFF666666),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: 17,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w700,
                          decoration: isAchieved 
                              ? TextDecoration.lineThrough 
                              : null,
                          decorationColor: milestone.color,
                          decorationThickness: 2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: isAchieved
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFFed3272),
                                  const Color(0xFFfd5d32),
                                ],
                              )
                            : null,
                        color: isAchieved ? null : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          color: isAchieved 
                              ? Colors.white 
                              : const Color(0xFF666666),
                          fontSize: 13,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  benefit,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimeRemaining(int minutes, AppLocalizations l10n) {
    if (minutes <= 0) return '';
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    
    if (hours > 0 && mins > 0) {
      return l10n
          .translate('fasting_time_remaining_hm')
          .replaceAll('{hours}', hours.toString())
          .replaceAll('{minutes}', mins.toString());
    } else if (hours > 0) {
      return l10n
          .translate('fasting_time_remaining_h')
          .replaceAll('{hours}', hours.toString());
    } else {
      return l10n
          .translate('fasting_time_remaining_m')
          .replaceAll('{minutes}', mins.toString());
    }
  }
}

class _MetaRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  const _MetaRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: _MetaCell(label: leftLabel, value: leftValue)),
          const SizedBox(width: 12),
          Expanded(child: _MetaCell(label: rightLabel, value: rightValue)),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  const _MetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
            letterSpacing: 1.1,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _WheelNumber extends StatefulWidget {
  final String label; final int min; final int max; final int value; final ValueChanged<int> onChanged;
  const _WheelNumber({required this.label, required this.min, required this.max, required this.value, required this.onChanged});
  @override
  State<_WheelNumber> createState() => _WheelNumberState();
}

class _WheelNumberState extends State<_WheelNumber> {
  late FixedExtentScrollController _c;
  @override
  void initState(){ super.initState(); _c = FixedExtentScrollController(initialItem: widget.value); }
  @override
  void dispose(){ _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context){
    return Column(
      children:[
        Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListWheelScrollView.useDelegate(
            controller: _c,
            onSelectedItemChanged: widget.onChanged,
            physics: const FixedExtentScrollPhysics(),
            itemExtent: 32,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index){
                if (index < widget.min || index > widget.max) return null;
                final selected = index == _c.selectedItem;
                return Center(
                  child: Text(index.toString().padLeft(2, '0'), style: TextStyle(fontSize: selected?20:18, color: selected? const Color(0xFF1A1A1A) : const Color(0xFF8E8E93), fontWeight: selected? FontWeight.w700: FontWeight.w500)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EndFastButton extends StatelessWidget {
  final VoidCallback onEnd;
  final String label;
  const _EndFastButton({required this.onEnd, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onEnd,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ).merge(ButtonStyle(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 0),
          ),
          overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
        )),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartFastButton extends StatelessWidget {
  final VoidCallback onStart;
  final String label;
  const _StartFastButton({required this.onStart, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ).merge(ButtonStyle(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 0),
          ),
          overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
        )),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsCards extends StatefulWidget {
  @override
  State<_StatisticsCards> createState() => _StatisticsCardsState();
}

class _StatisticsCardsState extends State<_StatisticsCards> {
  final _repo = FastingRepository();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return StreamBuilder<List<FastLog>>(
      stream: _repo.watchRecent(days: 90),
      builder: (context, logsSnapshot) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _loadStats(),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? {};
            final streak = stats['streak'] ?? 0;
            final weekCount = stats['weekCount'] ?? 0;
            final longestMinutes = stats['longestMinutes'] ?? 0;
            final monthCount = stats['monthCount'] ?? 0;
            
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('fasting_stats_title'),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactStatItem(
                          icon: Icons.local_fire_department,
                          value: streak.toString(),
                          label: l10n.translate('fasting_stats_streak'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CompactStatItem(
                          icon: Icons.calendar_today,
                          value: '$weekCount/7',
                          label: l10n.translate('fasting_stats_this_week'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactStatItem(
                          icon: Icons.timer,
                          value: _formatDuration(longestMinutes),
                          label: l10n.translate('fasting_stats_longest'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CompactStatItem(
                          icon: Icons.bar_chart,
                          value: monthCount.toString(),
                          label: l10n.translate('fasting_stats_this_month'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Future<Map<String, dynamic>> _loadStats() async {
    final streak = await _repo.getCurrentStreak();
    final weekCount = await _repo.getWeekCount();
    final longest = await _repo.getLongestFast();
    final monthCount = await _repo.getMonthCount();
    
    return {
      'streak': streak,
      'weekCount': weekCount,
      'longestMinutes': longest?.actualMinutes ?? 0,
      'monthCount': monthCount,
    };
  }
  
  String _formatDuration(int minutes) {
    if (minutes == 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}

class _CompactStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  
  const _CompactStatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentFastsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.translate('fasting_recent_fasts'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'ElzaRound',
            ),
          ),
        ),
        const SizedBox(height: 8),
        _MiniCompletionChart(),
      ],
    );
  }
}

String _formatElapsedSeconds(int seconds) {
  final int d = seconds ~/ (24 * 60 * 60);
  final int h = (seconds % (24 * 60 * 60)) ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  final int s = seconds % 60;
  final String hh = h.toString().padLeft(2, '0');
  final String mm = m.toString().padLeft(2, '0');
  final String ss = s.toString().padLeft(2, '0');
  final String dd = d.toString().padLeft(2, '0');
  return d > 0 ? '$dd:$hh:$mm' : '$hh:$mm:$ss';
}

String _fmtDateTime(DateTime? dt, AppLocalizations l10n) {
  if (dt == null) return '--';
  try {
    return DateFormat('EEE, h:mm a', l10n.locale.languageCode).format(dt);
  } catch (_) {
    return DateFormat('EEE, h:mm a').format(dt);
  }
}


class _BouncingArrow extends StatefulWidget {
  const _BouncingArrow();

  @override
  State<_BouncingArrow> createState() => _BouncingArrowState();
}

class _BouncingArrowState extends State<_BouncingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  late final Animation<double> _animation = Tween<double>(
    begin: 0,
    end: 8,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF666666).withOpacity(0.6),
            size: 28,
          ),
        );
      },
    );
  }
}

class _TopToastBanner extends StatefulWidget {
  final String text;
  const _TopToastBanner({required this.text});

  @override
  State<_TopToastBanner> createState() => _TopToastBannerState();
}

class _TopToastBannerState extends State<_TopToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, -0.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w700,
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

