import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import '../../data/repositories/fasting_repository.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'fasting_dashboard_screen.dart';
import 'package:stoppr/features/fasting/presentation/screens/fasting_info_screen.dart';

class FastingSetupScreen extends StatefulWidget {
  const FastingSetupScreen({super.key, this.repository, this.initialTargetMinutes});

  final FastingRepository? repository;
  final int? initialTargetMinutes; // optional preset target in minutes

  @override
  State<FastingSetupScreen> createState() => _FastingSetupScreenState();
}

class _FastingSetupScreenState extends State<FastingSetupScreen> {
  late final FastingRepository _repository;
  int _days = 0;
  int _hours = 16;
  int _minutes = 0;
  DateTime? _customStartAt; // null = start now

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FastingRepository();
    // Apply optional preset
    final preset = widget.initialTargetMinutes;
    if (preset != null && preset > 0) {
      _days = preset ~/ (24 * 60);
      _hours = (preset % (24 * 60)) ~/ 60;
      _minutes = preset % 60;
    }
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
          l10n.translate('fasting_setup_title'),
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
                child: _PickersRow(
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
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _onDone,
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
                    l10n.translate('fasting_done'),
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
      ),
    );
  }
  Future<void> _onDone() async {
    final totalMinutes = (_days * 24 * 60) + (_hours * 60) + _minutes;
    if (totalMinutes == 0) {
      // Show error message or prevent submission
      return;
    }
    final start = _customStartAt ?? DateTime.now();
    final endAt = start.add(Duration(minutes: totalMinutes));
    // Capture strings before navigation to avoid using context later
    final l10n = AppLocalizations.of(context)!;
    final startReminderTitle = l10n.translate('fasting_start_reminder_title');
    final startReminderBody = l10n.translate('fasting_start_reminder_body');

    // Persist first to ensure the dashboard counter starts instantly
    debugPrint('FastingSetupScreen: Start fast requested startAt=${start.toIso8601String()} totalMinutes=$totalMinutes');
    try {
      final log = await _repository.startFast(
        startAt: start,
        targetMinutes: totalMinutes,
      );
      debugPrint('FastingSetupScreen: Scheduling end reminder for fastId=${log.id} endAt=${endAt.toIso8601String()}');
      try {
        await NotificationService().scheduleFastingEndReminder(endAt: endAt);
      } catch (e) {
        debugPrint('FastingSetupScreen: scheduleFastingEndReminder failed: $e');
      }
      final now = DateTime.now();
      if (start.isAfter(now)) {
        try {
          await NotificationService().schedulePledgeCheckNotification(
            checkTime: start,
            title: startReminderTitle,
            body: startReminderBody,
          );
        } catch (e) {
          debugPrint('FastingSetupScreen: schedulePledgeCheckNotification failed: $e');
        }
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('FastingSetupScreen: startFast failed: $e');
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }
}

class _PickersRow extends StatelessWidget {
  final int days;
  final int hours;
  final int minutes;
  final void Function(int d, int h, int m) onChanged;
  const _PickersRow({
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
          child: _Wheel(
            label: l10n.translate('fasting_days'),
            min: 0,
            max: 60,
            value: days,
            onChanged: (v) => onChanged(v, hours, minutes),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Wheel(
            label: l10n.translate('fasting_hours'),
            min: 0,
            max: 23,
            value: hours,
            onChanged: (v) => onChanged(days, v, minutes),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Wheel(
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

class _Wheel extends StatelessWidget {
  final String label;
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;
  const _Wheel({
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

class _DatePickerDialogSimple extends StatefulWidget {
  const _DatePickerDialogSimple({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DatePickerDialogSimple> createState() => _DatePickerDialogSimpleState();
}

class _DatePickerDialogSimpleState extends State<_DatePickerDialogSimple> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalendarDatePicker(
              initialDate: _selected,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onDateChanged: (d) => setState(() => _selected = d),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Cancel (gray background)
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.translate('common_cancel'),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // OK (brand gradient CTA)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ).merge(ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Colors.transparent),
                        padding: MaterialStateProperty.all(EdgeInsets.zero),
                      )),
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Center(
                          child: Text(
                            l10n.translate('common_confirm'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


