import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';

import 'relapse_target_days_screen.dart';
import 'widgets/relapse_choice_chip.dart';

class RelapseHelpOrWorseScreen extends StatelessWidget {
  const RelapseHelpOrWorseScreen({super.key});

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
                l10n.translate('relapse_help_or_worse_title'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      RelapseChoiceChip(labelKey: 'relapse_help_worse_makes_worse', singleSelect: true),
                      RelapseChoiceChip(labelKey: 'relapse_help_worse_sometimes', singleSelect: true),
                      RelapseChoiceChip(labelKey: 'relapse_help_worse_escape', singleSelect: true),
                      RelapseChoiceChip(labelKey: 'relapse_help_worse_relieves_stress', singleSelect: true),
                      RelapseChoiceChip(labelKey: 'relapse_help_worse_boosts_mood_temporarily', singleSelect: true),
                    ],
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
                    Navigator.of(context).push(
                      FadePageRoute(
                        child: const RelapseTargetDaysScreen(),
                        settings: const RouteSettings(name: '/relapse/target_days'),
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


