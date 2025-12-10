import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/features/onboarding/presentation/screens/referral_code_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/current_6_blocks_rating_screen.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PotentialRatingScreen extends StatefulWidget {
  final List<String> selectedGoals;
  
  const PotentialRatingScreen({
    super.key,
    this.selectedGoals = const [],
  });

  @override
  State<PotentialRatingScreen> createState() => _PotentialRatingScreenState();
}

class _PotentialRatingScreenState extends State<PotentialRatingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final OnboardingProgressService _progressService = OnboardingProgressService();
  ScrollController? _scrollController;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();

    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);

    // Set status bar to dark icons for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Create animation with a subtle ease effect
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );

    // Mixpanel tracking
    MixpanelService.trackPageView('Onboarding Potential Rating Screen');

    // Start the animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
    });

    // Save current screen state
    _saveCurrentScreen();
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.potentialRatingScreen);
  }

  void _onScroll() {
    if (_scrollController == null) return;
    // Hide arrows as soon as user starts scrolling
    final shouldShow = _scrollController!.offset <= 0; // Hide immediately after any scroll
    if (_showScrollIndicator != shouldShow) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      bottom: 100, // Position above the continue button
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showScrollIndicator ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black.withOpacity(0.7),
                size: 40,
              ),
              Transform.translate(
                offset: const Offset(0, -8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black.withOpacity(0.6),
                  size: 40,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -16),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black.withOpacity(0.5),
                  size: 40,
                ),
              ),
            ],
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).moveY(
            begin: -8,
            end: 8,
            duration: 1.5.seconds,
            curve: Curves.easeInOut,
          ).fadeIn(duration: 600.ms),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up scroll controller
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // White background branding
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxHeight < 600;

                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              children: [
                                // Title
                                Text(
                                  AppLocalizations.of(context)!.translate('potentialRating_title'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A), // Consistent dark text
                                    letterSpacing: -1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 16),

                                // Subtitle
                                Text(
                                  AppLocalizations.of(context)!.translate('potentialRating_subtitle'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666), // Consistent gray text
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: isSmallScreen ? 20 : 24),

                                // Rating Cards Grid
                                AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _animation.value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - _animation.value)),
                                        child: _buildRatingGrid(isSmallScreen),
                                      ),
                                    );
                                  },
                                ),

                                SizedBox(height: isSmallScreen ? 20 : 24),
                              ],
                            ),
                          ),
                        ),

                        // Continue Button
                        GestureDetector(
                          onTap: () {
                            MixpanelService.trackEvent(
                              'Onboarding Potential Rating Screen: Button Tap',
                              properties: {
                                'button': 'See how will I improve',
                              },
                            );
                            
                            // Navigate to ReferralCodeScreen
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const ReferralCodeScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFed3272), // Strong pink/magenta
                                  Color(0xFFfd5d32), // Vivid orange
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.translate('potentialRating_continueButton'),
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                    
                    // Scroll indicator - only show if there are more than 6 blocks
                    if (_getDynamicRatings().length > 6) _buildScrollIndicator(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _calculateImprovement(int potentialScore, String category) {
    // Current scores from the previous screen
    final currentScores = {
      'overall': 42,
      'focus': 38,
      'confidence': 45,
      'energy': 35,
      'motivation': 37,
      'mood': 41,
      'relationships': 39,
      'libido': 33,
      'selfControl': 36,
      'pureThoughts': 40,
    };
    
    final currentScore = currentScores[category] ?? 42;
    final improvement = potentialScore - currentScore;
    
    return '+$improvement';
  }

  List<Map<String, dynamic>> _getDynamicRatings() {
    final l10n = AppLocalizations.of(context)!;
    
    // Default ratings if no goals are selected
    final defaultRatings = [
      {
        'title': l10n.translate('potentialRating_overall'),
        'score': 85,
        'improvement': _calculateImprovement(85, 'overall'),
        'isHighlighted': true,
        'key': 'overall',
      },
      {
        'title': l10n.translate('potentialRating_focus'),
        'score': 85,
        'improvement': _calculateImprovement(85, 'focus'),
        'isHighlighted': false,
        'key': 'focus',
      },
      {
        'title': l10n.translate('potentialRating_confidence'),
        'score': 88,
        'improvement': _calculateImprovement(88, 'confidence'),
        'isHighlighted': false,
        'key': 'confidence',
      },
      {
        'title': l10n.translate('potentialRating_energy'),
        'score': 81,
        'improvement': _calculateImprovement(81, 'energy'),
        'isHighlighted': false,
        'key': 'energy',
      },
      {
        'title': l10n.translate('potentialRating_motivation'),
        'score': 81,
        'improvement': _calculateImprovement(81, 'motivation'),
        'isHighlighted': false,
        'key': 'motivation',
      },
      {
        'title': l10n.translate('potentialRating_mood'),
        'score': 87,
        'improvement': _calculateImprovement(87, 'mood'),
        'isHighlighted': false,
        'key': 'mood',
      },
    ];

    // If no goals selected, return default ratings
    if (widget.selectedGoals.isEmpty) {
      return defaultRatings;
    }

    // Create individual rating blocks for each selected goal
    final List<Map<String, dynamic>> dynamicRatings = [];
    
    // Always include Overall as the first and highlighted block
    dynamicRatings.add({
      'title': l10n.translate('potentialRating_overall'),
      'score': 85,
      'improvement': _calculateImprovement(85, 'overall'),
      'isHighlighted': true,
      'key': 'overall',
    });

    // Goal to rating block mapping with individual blocks
    final goalToRatingMap = {
      'Stronger relationships': [
        {
          'title': l10n.translate('potentialRating_relationships'),
          'score': 83,
          'improvement': _calculateImprovement(83, 'relationships'),
          'key': 'relationships',
        }
      ],
      'Improved self-confidence': [
        {
          'title': l10n.translate('potentialRating_confidence'),
          'score': 88,
          'improvement': _calculateImprovement(88, 'confidence'),
          'key': 'confidence',
        }
      ],
      'Improved mood and happiness': [
        {
          'title': l10n.translate('potentialRating_mood'),
          'score': 87,
          'improvement': _calculateImprovement(87, 'mood'),
          'key': 'mood',
        }
      ],
      'More energy and motivation': [
        {
          'title': l10n.translate('potentialRating_energy'),
          'score': 81,
          'improvement': _calculateImprovement(81, 'energy'),
          'key': 'energy',
        },
        {
          'title': l10n.translate('potentialRating_motivation'),
          'score': 81,
          'improvement': _calculateImprovement(81, 'motivation'),
          'key': 'motivation',
        }
      ],
      'Improved libido and sex life': [
        {
          'title': l10n.translate('potentialRating_libido'),
          'score': 79,
          'improvement': _calculateImprovement(79, 'libido'),
          'key': 'libido',
        }
      ],
      'Improved self-control': [
        {
          'title': l10n.translate('potentialRating_selfControl'),
          'score': 82,
          'improvement': _calculateImprovement(82, 'selfControl'),
          'key': 'selfControl',
        }
      ],
      'Improved focus and clarity': [
        {
          'title': l10n.translate('potentialRating_focus'),
          'score': 85,
          'improvement': _calculateImprovement(85, 'focus'),
          'key': 'focus',
        }
      ],
      'Pure and healthy thoughts': [
        {
          'title': l10n.translate('potentialRating_pureThoughts'),
          'score': 84,
          'improvement': _calculateImprovement(84, 'pureThoughts'),
          'key': 'pureThoughts',
        }
      ],
    };

    // Add blocks for each selected goal
    for (final goal in widget.selectedGoals) {
      final ratingBlocks = goalToRatingMap[goal];
      if (ratingBlocks != null) {
        for (final block in ratingBlocks) {
          dynamicRatings.add({
            'title': block['title'],
            'score': block['score'],
            'improvement': block['improvement'],
            'isHighlighted': false,
            'key': block['key'],
          });
        }
      }
    }

    return dynamicRatings;
  }

  Widget _buildRatingGrid(bool isSmallScreen) {
    // Get dynamic ratings based on selected goals
    final ratings = _getDynamicRatings();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: ratings.length,
      itemBuilder: (context, index) {
        final rating = ratings[index];
        final isHighlighted = rating['isHighlighted'] as bool;

        return Container(
          decoration: BoxDecoration(
            gradient: isHighlighted ? const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFed3272), // Strong pink/magenta
                Color(0xFFfd5d32), // Vivid orange
              ],
            ) : null,
            color: isHighlighted ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? Colors.transparent : Colors.grey.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon and title with improvement badge
                Row(
                  children: [
                    _getRatingIcon(rating['title'] as String, isHighlighted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rating['title'] as String,
                        style: TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isHighlighted ? Colors.white : const Color(0xFF1A1A1A), // Consistent dark text
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                // Score with improvement badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rating['score']}',
                      style: TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: isHighlighted ? Colors.white : const Color(0xFF1A1A1A), // Consistent dark text
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isHighlighted ? Colors.white : const Color(0xFFed3272), // Brand pink for normal cards
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rating['improvement'] as String,
                            style: TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isHighlighted ? const Color(0xFFed3272) : Colors.white, // Brand pink text on highlighted
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_upward,
                            size: 14,
                            color: isHighlighted ? const Color(0xFFed3272) : Colors.white, // Brand pink icon on highlighted
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Progress bar
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isHighlighted 
                        ? Colors.white.withOpacity(0.3) 
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (rating['score'] as int) / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHighlighted ? Colors.white : const Color(0xFFed3272), // Brand pink for progress bar
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getRatingIcon(String title, bool isHighlighted) {
    final l10n = AppLocalizations.of(context)!;
    Color iconColor = isHighlighted ? Colors.white : const Color(0xFF1A1A1A); // Consistent dark icons
    
    // Match against localized strings
    if (title == l10n.translate('potentialRating_overall')) {
      return Icon(Icons.star, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_focus')) {
      return Icon(Icons.center_focus_strong, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_confidence')) {
      return Icon(Icons.psychology, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_energy')) {
      return Icon(Icons.bolt, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_motivation')) {
      return Icon(Icons.trending_up, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_mood')) {
      return Icon(Icons.mood, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_relationships')) {
      return Icon(Icons.favorite, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_libido')) {
      return Icon(Icons.favorite_border, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_selfControl')) {
      return Icon(Icons.pan_tool_outlined, color: iconColor, size: 20);
    } else if (title == l10n.translate('potentialRating_pureThoughts')) {
      return Icon(Icons.spa, color: iconColor, size: 20);
    } else {
      return Icon(Icons.star, color: iconColor, size: 20);
    }
  }
} 