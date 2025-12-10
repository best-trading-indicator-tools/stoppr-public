import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class WorkoutEnergyInfoScreen extends StatelessWidget {
  const WorkoutEnergyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppLocalizations.of(context)!.translate('workout_energy_info_title'), style: const TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black),
            onPressed: () async {
              MixpanelService.trackButtonTap('Help & Info', screenName: 'Workout Energy Info Screen');
              final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.inAppWebView);
                }
              } catch (_) {}
            },
            tooltip: AppLocalizations.of(context)!.translate('pledgeScreen_tooltip_help'),
          ),
        ],
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.translate('workout_energy_met_what_is'), style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.translate('workout_energy_explainer_header'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.translate('workout_energy_explainer_body'),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.translate('workout_energy_mets_header'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.translate('workout_energy_met_examples'),
              style: const TextStyle(fontSize: 16, height: 1.5),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.translate('workout_energy_disclaimer_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.translate('workout_energy_disclaimer_body'), style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }
}


