import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/features/onboarding/presentation/screens/potential_rating_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/choose_goals_onboarding.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Current6BlocksRatingScreen extends StatefulWidget {
  final List<String> selectedGoals;
  
  const Current6BlocksRatingScreen({
    super.key,
    this.selectedGoals = const [],
  });

  @override
  State<Current6BlocksRatingScreen> createState() => _Current6BlocksRatingScreenState();
}

class _Current6BlocksRatingScreenState extends State<Current6BlocksRatingScreen>
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

    // Set status bar to dark icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Create animation with a subtle ease effect
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );

    // Mixpanel tracking
    MixpanelService.trackPageView('Onboarding Current 6 Blocks Rating Screen');

    // Start the animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
    });

    // Save current screen state
    _saveCurrentScreen();
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.current6BlocksRatingScreen);
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
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF1A1A1A), // Dark arrows for white background
                  size: 40,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -8),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF1A1A1A), // Dark arrows for white background
                    size: 40,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF1A1A1A), // Dark arrows for white background
                    size: 40,
                  ),
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
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
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
                                  AppLocalizations.of(context)!.translate('currentRiseRating_title'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A), // Dark text for white background
                                    letterSpacing: -1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 16),

                                // Subtitle
                                Text(
                                  AppLocalizations.of(context)!.translate('currentRiseRating_subtitle'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666), // Dark gray text for white background
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
                              'Onboarding Current 6 Blocks Rating Screen: Button Tap',
                              properties: {
                                'button': 'See potential rating',
                              },
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PotentialRatingScreen(
                                  selectedGoals: widget.selectedGoals,
                                ),
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
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.translate('currentRiseRating_continueButton'),
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

  List<Map<String, dynamic>> _getDynamicRatings() {
    final l10n = AppLocalizations.of(context)!;
    
    // Default ratings if no goals are selected
    final defaultRatings = [
      {
        'title': l10n.translate('currentRiseRating_overall'),
        'score': 42,
        'isHighlighted': true,
        'key': 'overall',
      },
      {
        'title': l10n.translate('currentRiseRating_focus'),
        'score': 38,
        'isHighlighted': false,
        'key': 'focus',
      },
      {
        'title': l10n.translate('currentRiseRating_confidence'),
        'score': 45,
        'isHighlighted': false,
        'key': 'confidence',
      },
      {
        'title': l10n.translate('currentRiseRating_energy'),
        'score': 35,
        'isHighlighted': false,
        'key': 'energy',
      },
      {
        'title': l10n.translate('currentRiseRating_motivation'),
        'score': 37,
        'isHighlighted': false,
        'key': 'motivation',
      },
      {
        'title': l10n.translate('currentRiseRating_mood'),
        'score': 41,
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
      'title': l10n.translate('currentRiseRating_overall'),
      'score': 42,
      'isHighlighted': true,
      'key': 'overall',
    });

    // Goal to rating block mapping with individual blocks
    final goalToRatingMap = {
      'Stronger relationships': [
        {
          'title': l10n.translate('currentRiseRating_relationships'),
          'score': 39,
          'key': 'relationships',
        }
      ],
      'Improved self-confidence': [
        {
          'title': l10n.translate('currentRiseRating_confidence'),
          'score': 45,
          'key': 'confidence',
        }
      ],
      'Improved mood and happiness': [
        {
          'title': l10n.translate('currentRiseRating_mood'),
          'score': 41,
          'key': 'mood',
        }
      ],
      'More energy and motivation': [
        {
          'title': l10n.translate('currentRiseRating_energy'),
          'score': 35,
          'key': 'energy',
        },
        {
          'title': l10n.translate('currentRiseRating_motivation'),
          'score': 37,
          'key': 'motivation',
        }
      ],
      'Improved libido and sex life': [
        {
          'title': l10n.translate('currentRiseRating_libido'),
          'score': 33,
          'key': 'libido',
        }
      ],
      'Improved self-control': [
        {
          'title': l10n.translate('currentRiseRating_selfControl'),
          'score': 36,
          'key': 'selfControl',
        }
      ],
      'Improved focus and clarity': [
        {
          'title': l10n.translate('currentRiseRating_focus'),
          'score': 38,
          'key': 'focus',
        }
      ],
      'Pure and healthy thoughts': [
        {
          'title': l10n.translate('currentRiseRating_pureThoughts'),
          'score': 40,
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
            color: isHighlighted ? const Color(0xFF2A2A2A) : Colors.white, // Inverse: dark when highlighted, white when normal
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? Colors.transparent : const Color(0xFFE0E0E0), // Light border for normal cards
              width: isHighlighted ? 0 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon and title
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
                          color: isHighlighted ? Colors.white : const Color(0xFF1A1A1A), // Inverse: white text on dark, dark text on white
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Score
                Text(
                  '${rating['score']}',
                  style: TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: isHighlighted ? Colors.white : const Color(0xFF1A1A1A), // Inverse: white text on dark, dark text on white
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 6),

                // Progress bar
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isHighlighted 
                        ? Colors.white.withOpacity(0.2) // Light background on dark card
                        : const Color(0xFFE0E0E0), // Light gray background on white card
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (rating['score'] as int) / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHighlighted ? Colors.white : const Color(0xFF1A1A1A), // Inverse: white progress on dark, dark progress on white
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
    Color iconColor = isHighlighted ? Colors.white : const Color(0xFF1A1A1A); // Inverse: white icons on dark, dark icons on white
    
    // Match against localized strings
    if (title == l10n.translate('currentRiseRating_overall')) {
      return Icon(Icons.star, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_focus')) {
      return Icon(Icons.center_focus_strong, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_confidence')) {
      return Icon(Icons.psychology, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_energy')) {
      return Icon(Icons.bolt, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_motivation')) {
      return Icon(Icons.trending_up, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_mood')) {
      return Icon(Icons.mood, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_relationships')) {
      return Icon(Icons.favorite, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_libido')) {
      return Icon(Icons.favorite_border, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_selfControl')) {
      return Icon(Icons.pan_tool_outlined, color: iconColor, size: 20);
    } else if (title == l10n.translate('currentRiseRating_pureThoughts')) {
      return Icon(Icons.spa, color: iconColor, size: 20);
    } else {
      return Icon(Icons.star, color: iconColor, size: 20);
    }
  }
} 