import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart';

class ScientificSourcesSlide extends BaseSlide {
  const ScientificSourcesSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (alternative.sources == null || alternative.sources!.isEmpty) {
      return buildSlideCard(
        title: AppLocalizations.of(context)!.translate('foodScan_scientificSourcesTitle'),
        icon: Icons.science_outlined,
        content: Center(child: Text(AppLocalizations.of(context)!.translate('foodScan_noScientificSources'))),
        titleColor: const Color(0xFFed3272), // Brand pink
      );
    }
    
    return buildSlideCard(
      title: AppLocalizations.of(context)!.translate('foodScan_scienceBehindTitle'),
      icon: Icons.science_outlined,
      content: _buildSourcesContent(context),
      titleColor: const Color(0xFFed3272), // Brand pink
    );
  }

  Widget _buildSourcesContent(BuildContext context) {
    final sources = alternative.sources!;

    // Apply staggered animation to source cards
    final animatedWidgets = createAnimatedChildren(
      sources.asMap().entries.map((entry) {
        final index = entry.key;
        final source = entry.value;
        return _buildSourceCard(context, source, index);
      }).toList(),
      seed: 6 // Use another seed
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add an intro text
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, // Clean white card background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2), width: 1), // Brand pink border
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Row(
              children: [
                Icon(
                  Icons.biotech_outlined,
                  color: const Color(0xFFed3272), // Brand pink
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.translate('scientificSources_description'),
                    style: const TextStyle(
                      color: Color(0xFF666666), // Gray text for secondary info
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0, duration: 600.ms),

          // Use the animated widgets list here
          ...animatedWidgets,
          const SizedBox(height: 30),
          _buildDecorativeElements(), // Add decorative elements
        ],
      ),
    );
  }

  // Build a styled card for each source
  Widget _buildSourceCard(BuildContext context, Source source, int index) {
    final bool hasUrl = source.url != null && source.url!.isNotEmpty;
    final Color accentColor = const Color(0xFFed3272); // Brand pink

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, // Clean white card background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
          width: 1.5,
        ),
         boxShadow: [
          BoxShadow(
            color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            source.title,
            style: const TextStyle(
              color: Color(0xFFed3272), // Brand pink for title
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          
          // Authors (if available)
          if (source.authors != null && source.authors!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: const Color(0xFF666666), size: 16), // Gray icon
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      source.authors!,
                      style: const TextStyle(
                        color: Color(0xFF666666), // Gray text for secondary info
                        fontFamily: 'ElzaRound',
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          // Publication & Year (if available)
          if (source.publication != null || source.year != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: const Color(0xFF666666), size: 16), // Gray icon
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${source.publication ?? 'N/A'} (${source.year ?? 'N/A'})',
                      style: const TextStyle(
                        color: Color(0xFF666666), // Gray text for secondary info
                        fontFamily: 'ElzaRound',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          // Description (if available)
          if (source.description != null && source.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0, top: 4.0),
              child: Text(
                source.description!,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            
          // URL (if available and tappable)
          if (hasUrl)
            InkWell(
              onTap: () => _launchURL(source.url!), // Launch URL on tap
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Keep row tight
                  children: [
                    Icon(Icons.link, color: accentColor, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context)!.translate('scientificSources_viewSource'), // Clearer text
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'ElzaRound',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: accentColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                     Icon(Icons.open_in_new, color: accentColor.withOpacity(0.7), size: 14), // Added icon
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper function to launch URL
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication); // Open in external browser
    } else {
      debugPrint('Could not launch $urlString');
      // Optionally show a snackbar or alert to the user
    }
  }
  
  // Add decorative elements
  Widget _buildDecorativeElements() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            Icons.science_outlined,
            color: const Color(0xFFed3272).withOpacity(0.2 + index * 0.2), // Brand pink with varying opacity
            size: 20 + index * 4,
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).shimmer(
            duration: (2 + index * 0.5).seconds,
            delay: (index * 200).ms,
            color: const Color(0xFFfd5d32), // Brand orange shimmer
          ).rotate(
            duration: (3 + index).seconds,
            begin: -0.05,
            end: 0.05
          ),
        );
      }),
    );
  }
} 