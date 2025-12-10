import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for launching URLs
import 'package:stoppr/core/localization/app_localizations.dart'; // Import AppLocalizations

// This widget is now designed to be the child of a ModalBottomSheet
class InfoModalContent extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final String imageAssetPath;
  final String healthReportUrl = 
      'https://elevenlife.notion.site/Stoppr-App-Health-Information-and-Scientific-References-1c3456d8905e80029856d5373ee08dfb?pvs=4';

  const InfoModalContent({
    Key? key,
    required this.title,
    required this.description,
    required this.buttonText,
    this.onButtonPressed,
    required this.imageAssetPath,
  }) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      // Consider logging this error or showing a message to the user
      // For now, just printing to console as an example
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Get l10n instance
    return Container(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 32.0), // Added bottom padding for safe area
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            imageAssetPath,
            height: 48,
            width: 48,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 48),
          ),
          const SizedBox(height: 16.0),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'ElzaRoundVariable',
                  fontWeight: FontWeight.bold, 
                  fontSize: 22,
                  color: const Color(0xFF20303F), 
                  height: 22.5 / 22, // Figma: 22.5 line height for 22 font size
                  letterSpacing: 0, // Figma: 0px
                ),
          ),
          const SizedBox(height: 16.0),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'ElzaRoundVariable',
                  fontWeight: FontWeight.w500, // Medium weight
                  fontSize: 15,
                  color: const Color(0xFF20303F),
                  height: 1.7, // Corresponds to 170% line height
                  letterSpacing: 0.15, // 1% of 15px
                ),
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: const Color(0xFF1E1E1E), // Updated text color
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 0,
            ),
            onPressed: onButtonPressed ?? () => Navigator.of(context).pop(),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontFamily: 'ElzaRoundVariable',
                fontWeight: FontWeight.w600, // Semibold
                fontSize: 17,
                height: 0.9,
                letterSpacing: 0,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
          const SizedBox(height: 16.0), // Spacing before the link
          TextButton(
            onPressed: () => _launchUrl(healthReportUrl),
            child: Text(
              l10n.translate('infoModal_healthReportLink'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ElzaRoundVariable',
                fontWeight: FontWeight.w700, // Semibold
                fontSize: 18,
                height: 0.9,
                letterSpacing: 0,
                color: Color(0x80808080), // #808080 with 50% opacity
                decoration: TextDecoration.none, // No underline
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated to use showModalBottomSheet
Future<void> showInfoModalBottomSheet({
  required BuildContext context,
  required String titleKey,
  required String descriptionKey,
  required String imageAssetPath,
  String buttonTextKey = 'common_dismiss',
}) {
  final l10n = AppLocalizations.of(context)!;

  final String localizedTitle = l10n.translate(titleKey);
  final String localizedDescription = l10n.translate(descriptionKey);
  final String localizedButtonText = l10n.translate(buttonTextKey);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // Important for content to determine height
    backgroundColor: Colors.transparent, // Make sheet background transparent
    barrierColor: Colors.black.withOpacity(0.6), // Dimming color for background
    builder: (BuildContext dialogContext) {
      return InfoModalContent(
        title: localizedTitle,
        description: localizedDescription,
        imageAssetPath: imageAssetPath,
        buttonText: localizedButtonText,
        onButtonPressed: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
} 