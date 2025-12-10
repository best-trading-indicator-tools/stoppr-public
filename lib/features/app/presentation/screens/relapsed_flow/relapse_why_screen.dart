import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'relapse_help_worse_screen.dart';
import 'widgets/relapse_choice_chip.dart';

class RelapseWhyScreen extends StatelessWidget {
  static const String routeName = '/relapse/why';

  const RelapseWhyScreen({super.key});

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
                l10n.translate('relapse_why_recently_title'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  height: 1.2,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('relapse_why_recently_subtitle_multi'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      RelapseChoiceChip(labelKey: 'relapse_reason_boredom'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_strong_urges'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_sad'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_loneliness'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_stress'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_social_pressure'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_cravings_after_meals'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_sleep_deprivation'),
                      RelapseChoiceChip(labelKey: 'relapse_reason_other'),
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
                        child: const RelapseHelpOrWorseScreen(),
                        settings: const RouteSettings(name: '/relapse/help_or_worse'),
                      ),
                    );
                  },
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272),
                          Color(0xFFfd5d32),
                        ],
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


