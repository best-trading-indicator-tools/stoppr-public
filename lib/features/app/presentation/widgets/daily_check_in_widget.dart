import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../screens/meditate_screen.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/services/video_player_defensive_service.dart';
import 'package:flutter/cupertino.dart'; // Import for CupertinoPageRoute
import '../../../../core/localization/app_localizations.dart';
import 'package:flutter_emoji/flutter_emoji.dart';
// Summary: Add Crashlytics context key so native video crashes are attributed to this widget.
import '../../../../core/analytics/crashlytics_service.dart';
import 'package:stoppr/core/streak/streak_service.dart';

class DailyCheckInWidget extends StatefulWidget {
  final int usersCount;
  final VoidCallback onStillGoingStrong;
  final VoidCallback onRelapsed;
  final Function(String) onMoodSelected;
  final VoidCallback onReflect;
  final VoidCallback? onAnimationComplete;

  const DailyCheckInWidget({
    super.key,
    required this.usersCount,
    required this.onStillGoingStrong,
    required this.onRelapsed,
    required this.onMoodSelected,
    required this.onReflect,
    this.onAnimationComplete,
  });

  @override
  State<DailyCheckInWidget> createState() => DailyCheckInWidgetState();
}

class DailyCheckInWidgetState extends State<DailyCheckInWidget> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _showMoodCheck = false;
  bool _showMoodStats = false;
  String _selectedMood = '';
  bool _hasRelapsed = false; // Track whether user has relapsed
  
  // Mood distribution percentages
  final Map<String, double> _moodDistribution = {
    'happy': 0.69,    // 69% happy
    'neutral': 0.25,   // 25% neutral
    'sad': 0.06,      // 6% sad
  };
  
  // Animation controller for slide up
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  
  // Emoji parser for consistent rendering across platforms
  final EmojiParser _emojiParser = EmojiParser();
  // Key to compute content bounds for outside-tap detection
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setCustomKey('video_init_context', 'DailyCheckInWidget');
    _initializeVideo();
    _initializeAnimation();
  }
  
  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),  // Start from bottom
      end: Offset.zero,           // End at original position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    if (_isVideoInitialized) {
      _videoController.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = await VideoPlayerDefensiveService.initializeWithDefensiveMeasures(
        videoPath: 'assets/videos/daily_widget.mp4',
        isNetworkUrl: false,
        context: 'DailyCheckInWidget',
      );
      
      await _videoController.setLooping(true);
      _videoController.play();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      // If video loading fails, still show check-in but without video
      debugPrint('Error loading video: $e');
    }
  }
  
  void _handleStillGoingStrong() {
    if (mounted) {
      setState(() {
        _showMoodCheck = true;
      });
    }
  }
  
  void _handleMoodSelected(String mood) {
    if (mounted) {
      setState(() {
        _selectedMood = mood;
        _showMoodCheck = false;
        _showMoodStats = true;
      });
      
      // If user indicated they relapsed, notify parent
      if (_hasRelapsed) {
        widget.onRelapsed();
      }
    }
  }
  
  void _handleReflect() {
    if (!mounted) return;
    
    // MIXPANEL_COST_CUT: Track consolidated daily check-in completion
    MixpanelService.trackEvent('Daily Check-in Completed', properties: {
      'outcome': 'reflect',
      'mood': _selectedMood,
      'has_relapsed': _hasRelapsed,
    });
    
    // If the user relapsed and already picked a mood, reset streak before dismiss
    if (_hasRelapsed && _selectedMood.isNotEmpty) {
      StreakService().resetStreakCounter();
    }

    // Animate out and call the reflect callback
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => const MeditateScreen(),
            settings: const RouteSettings(name: '/meditate'),
          ),
        );
      }
    });
  }
  
  void _handleFinish() {
    if (!mounted) return;
    
    // MIXPANEL_COST_CUT: Track consolidated daily check-in completion
    MixpanelService.trackEvent('Daily Check-in Completed', properties: {
      'outcome': 'finished',
      'mood': _selectedMood,
      'has_relapsed': _hasRelapsed,
    });
    
    // If the user relapsed and already picked a mood, reset streak before dismiss
    if (_hasRelapsed && _selectedMood.isNotEmpty) {
      StreakService().resetStreakCounter();
    }

    // Call the mood selected callback to notify the parent immediately
    widget.onMoodSelected(_selectedMood);
    
    // Directly trigger animation and call animation complete callback
    _animationController.reverse();
    
    // Call the onAnimationComplete callback directly, not waiting for animation
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }
  
  // Calculate mood counts based on total users and distribution percentages
  int _getMoodCount(String mood) {
    final percentage = _moodDistribution[mood] ?? 0.0;
    return (widget.usersCount * percentage).round();
  }
  
  // Helper method to render emojis consistently across platforms
  String _getConsistentEmoji(String emojiName) {
    final emoji = _emojiParser.get(emojiName);
    return emoji.code.isNotEmpty ? emoji.code : emojiName;
  }

  // Public method to start the slide-down animation
  void animateOut() {
    _animationController.reverse().then((_) {
      if (mounted && widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
    });
  }
  
  // Handle tap outside the widget
  void _handleOutsideTap() {
    if (!mounted) return;
    
    // MIXPANEL_COST_CUT: Removed tracking for tap outside (micro-interaction)
    
    // If the user relapsed and already picked a mood, reset streak before dismiss
    if (_hasRelapsed && _selectedMood.isNotEmpty) {
      StreakService().resetStreakCounter();
    }

    // Directly trigger animation and call animation complete callback
    _animationController.reverse();
    
    // Call the onAnimationComplete callback directly, not waiting for animation
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    
    // First, create the content widget
    Widget content = Material(
      type: MaterialType.transparency, // Use transparency to keep your current styling
      child: Container(
        key: _contentKey,
        height: size.height * 0.7, // Increased from 0.65 to 0.7 to give more room for buttons
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A051D), // Fallback color if video fails
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video background covering the entire container
            if (_isVideoInitialized)
              Positioned.fill(
                child: VideoPlayer(_videoController),
              ),
            
            // Simple full overlay with solid color at 50% opacity for better text visibility
            Positioned.fill(
              child: Container(
                color: const Color(0x80000000), // 50% opacity black for better contrast
              ),
            ),
            
            // Content with padding
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), // Increased bottom padding
              child: _showMoodStats 
                  ? _buildMoodStatsView(l10n) 
                  : (_showMoodCheck ? _buildMoodCheckView(l10n) : _buildRelapseCheckView(l10n)),
            ),
          ],
        ),
      ),
    );
    
    // Improved stack structure to handle taps correctly
    return Stack(
      children: [
        // Transparent full-screen area to detect taps outside - positioned behind content
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              // Only dismiss when tapping outside the content bounds
              final renderObject = _contentKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderObject == null) {
                _handleOutsideTap();
                return;
              }
              final topLeft = renderObject.localToGlobal(Offset.zero);
              final size = renderObject.size;
              final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
              if (!rect.contains(details.globalPosition)) {
                _handleOutsideTap();
              }
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // The actual widget (positioned at bottom and should receive touches first)
        Positioned(
          bottom: 0, // Start from the bottom edge of the screen
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: content,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRelapseCheckView(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Add this to prevent unbounded height issues
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Push content down instead of up by using positive offset
        Transform.translate(
          offset: const Offset(0, -10), // Changed from -70 to 30 to push content down
          child: Column(
            mainAxisSize: MainAxisSize.min, // Add this to prevent unbounded height issues
            children: [
              // Add some top padding
              const SizedBox(height: 20),
              
              // Eyes icon
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    _getConsistentEmoji('eyes'),
                    style: const TextStyle(
                      fontSize: 30,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Question text - Changed from Flexible to regular widget
              Text(
                l10n.translate('dailyCheckIn_relapseQuestion'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Color(0x88000000),
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.visible,
                maxLines: 3,
              ),
              
              const SizedBox(height: 30),
              
              // User count
              Text(
                widget.usersCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Color(0x88000000),
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 5),
              
              // "are still going strong" text - Changed from Flexible to regular widget
              Text(
                l10n.translate('dailyCheckIn_stillGoingStrongCount'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Color(0x88000000),
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.visible,
                maxLines: 2,
              ),
              
              const SizedBox(height: 30),
              
              // Buttons row
              Row(
                children: [
                  // "No, still going strong" button
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFed3272), // Brand pink
                            Color(0xFFfd5d32), // Brand orange
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: ElevatedButton(
                        onPressed: _handleStillGoingStrong,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.translate('dailyCheckIn_noStillGoingStrong'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                              fontSize: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              
              // "Yes, I relapsed" button - Secondary style for negative action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // MIXPANEL_COST_CUT: Removed individual relapse button tracking
                        // Show mood selection instead of closing
                        if (mounted) {
                          setState(() {
                            _showMoodCheck = true;
                            _hasRelapsed = true; // Mark that user has relapsed
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFed3272), // Brand pink text
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(
                          color: Color(0xFFed3272), // Brand pink border
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.translate('dailyCheckIn_yesRelapsed'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                            fontSize: 19,
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
      ],
    );
  }
  
  Widget _buildMoodCheckView(AppLocalizations l10n) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7 - 40, // Updated to match new container height
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          
          // Question text - Changed from Flexible to regular widget
          Text(
            l10n.translate('dailyCheckIn_howFeeling'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Color(0x88000000),
                  offset: Offset(1, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: 3,
          ),
          
          const Spacer(flex: 2),
          
          // Happy mood button
          _buildMoodButton(
            emoji: _getConsistentEmoji('blush'),
            color: const Color(0xFFfd5d32), // Brand orange for positive
            onTap: () => _handleMoodSelected('happy'),
          ),
          
          const SizedBox(height: 20),
          
          // Neutral mood button
          _buildMoodButton(
            emoji: _getConsistentEmoji('neutral_face'),
            color: const Color(0xFF666666), // Brand secondary gray
            onTap: () => _handleMoodSelected('neutral'),
          ),
          
          const SizedBox(height: 20),
          
          // Bad mood button
          _buildMoodButton(
            emoji: _getConsistentEmoji('pensive'),
            color: const Color(0xFFed3272), // Brand pink for emphasis
            onTap: () => _handleMoodSelected('sad'),
          ),
          
          const Spacer(flex: 3),
        ],
      ),
    );
  }
  
  Widget _buildMoodStatsView(AppLocalizations l10n) {
    final happyCount = (widget.usersCount * _moodDistribution['happy']!).round();
    final neutralCount = (widget.usersCount * _moodDistribution['neutral']!).round();
    final sadCount = widget.usersCount - happyCount - neutralCount;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Add this to prevent unbounded height issues
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Adjust transform to push content down
          Transform.translate(
            offset: const Offset(0, 40), // Changed from 15 to 40 to push content down
            child: Column(
              mainAxisSize: MainAxisSize.min, // Add this to prevent unbounded height issues
              children: [
                //const SizedBox(height: 20), // Added extra top padding
                // Motivational header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.translate('dailyCheckIn_believeInYou'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Color(0x88000000),
                          offset: Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    maxLines: 3,
                  ),
                ),
                
                const SizedBox(height: 20), // Reduced from 30
                
                // Mood statistics
                _buildMoodStat(
                  emoji: _getConsistentEmoji('blush'),
                  count: happyCount,
                ),
                
                const SizedBox(height: 10), // Reduced from 15
                
                _buildMoodStat(
                  emoji: _getConsistentEmoji('neutral_face'),
                  count: neutralCount,
                ),
                
                const SizedBox(height: 10), // Reduced from 15
                
                _buildMoodStat(
                  emoji: _getConsistentEmoji('pensive'),
                  count: sadCount,
                ),
                
                const SizedBox(height: 20), // Reduced from 25
                
                // Supportive message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.translate('dailyCheckIn_notAlone'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Color(0x88000000),
                          offset: Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    maxLines: 2,
                  ),
                ),
                
                const SizedBox(height: 20), // Reduced from 25
                
                // Reflect button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Brand pink
                          Color(0xFFfd5d32), // Brand orange
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _handleReflect,
                      icon: const Icon(Icons.refresh, size: 22, color: Colors.white),
                      label: Text(
                        l10n.translate('dailyCheckIn_reflect'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10), // Reduced from 15
                
                // Finish button - Secondary button style
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: _handleFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A1A1A), // Brand dark text
                      minimumSize: const Size(double.infinity, 45),
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0), // Light gray border
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.translate('dailyCheckIn_finish'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 25), // Increased to ensure button is fully touchable
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMoodStat({
    required String emoji,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 32, // Reduced from 36
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child:               Text(
                '$count others',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 28,
                  shadows: [
                    Shadow(
                      color: Color(0x88000000),
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMoodButton({
    required String emoji,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(
              fontSize: 40,
            ),
          ),
        ),
      ),
    );
  }
} 