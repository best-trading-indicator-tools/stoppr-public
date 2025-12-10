import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';

import 'relapse_signature_screen.dart';

class RelapseTargetDaysScreen extends StatefulWidget {
  const RelapseTargetDaysScreen({super.key});

  @override
  State<RelapseTargetDaysScreen> createState() => _RelapseTargetDaysScreenState();
}

class _RelapseTargetDaysScreenState extends State<RelapseTargetDaysScreen> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: 6);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('relapse_target_days_title'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  height: 1.2,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: 220,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          child: ListWheelScrollView.useDelegate(
                            controller: _controller,
                            physics: const FixedExtentScrollPhysics(),
                            itemExtent: 46,
                            perspective: 0.002,
                            diameterRatio: 2.2,
                            overAndUnderCenterOpacity: 0.35,
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 90,
                              builder: (context, index) {
                                final day = index + 1;
                                return Center(
                                  child: Text(
                                    '$day',
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.translate('relapse_days_suffix'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final int selectedDays = _controller.selectedItem + 1;
                    Navigator.of(context).push(
                      FadePageRoute(
                        child: RelapseSignatureScreen(targetDays: selectedDays),
                        settings: const RouteSettings(name: '/relapse/signature'),
                      ),
                    );
                  },
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


