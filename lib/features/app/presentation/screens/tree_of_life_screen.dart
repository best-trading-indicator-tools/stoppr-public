import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/tree/tree_of_life_service.dart';
import 'package:stoppr/features/app/presentation/widgets/tree_of_life_widget.dart';

class TreeOfLifeScreen extends StatefulWidget {
  static const String screenName = 'Tree of Life Screen';
  
  const TreeOfLifeScreen({super.key});

  @override
  State<TreeOfLifeScreen> createState() => _TreeOfLifeScreenState();
}

class _TreeOfLifeScreenState extends State<TreeOfLifeScreen>
    with TickerProviderStateMixin {
  final StreakService _streakService = StreakService();
  final TreeOfLifeService _treeService = TreeOfLifeService();
  
  late AnimationController _backgroundAnimationController;
  late Animation<double> _backgroundAnimation;
  
  bool _hasPlantedTree = false;
  
  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackEvent('Tree of Life Screen: Page Viewed');
    
    // Initialize background fade animation
    _backgroundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _loadTreePlantedState();
    _backgroundAnimationController.forward();
  }
  
  Future<void> _loadTreePlantedState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPlanted = prefs.getBool('tree_has_been_planted') ?? false;
    if (mounted) {
      setState(() {
        _hasPlantedTree = hasPlanted;
      });
    }
  }
  
  Future<void> _saveTreePlantedState(bool hasPlanted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tree_has_been_planted', hasPlanted);
    if (mounted) {
      setState(() {
        _hasPlantedTree = hasPlanted;
      });
    }
  }
  
  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.black, // Prevent white flash
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            MixpanelService.trackButtonTap(
              'Back',
              screenName: TreeOfLifeScreen.screenName,
            );
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          l10n.translate('treeOfLife_title'),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'ElzaRound',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _backgroundAnimation,
        child: Stack(
          children: [
            // Background image layer
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/home/garden.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            // Gradient overlay for better text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            
            // Main content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20), // Space below app bar
                  
                  // Tree widget (main content) - takes up most space
                  Expanded(
                    child: Center(
                      child: TreeOfLifeWidget(
                        showPlantButton: false, // Button is at the bottom
                        onPlantPressed: _handlePlantTreePressed,
                      ),
                    ),
                  ),
                  
                  // Unified growth message section with days count
                  _buildInspirationSection(l10n),
                  
                  const SizedBox(height: 20),
                  
                  // Plant tree button at bottom
                  _buildBottomPlantButton(l10n),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInspirationSection(AppLocalizations l10n) {
    return StreamBuilder<StreakData>(
      stream: _streakService.streakStream,
      initialData: _streakService.currentStreak,
      builder: (context, snapshot) {
        final streakData = snapshot.data ?? const StreakData(
          days: 0,
          hours: 0,
          minutes: 0,
          seconds: 0,
          startTime: null,
        );
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                l10n.translate('treeOfLife_growthMessage'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                '${streakData.days} ${l10n.translate('treeOfLife_days')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                l10n.translate('treeOfLife_encouragement'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomPlantButton(AppLocalizations l10n) {
    return StreamBuilder<StreakData>(
      stream: _streakService.streakStream,
      initialData: _streakService.currentStreak,
      builder: (context, snapshot) {
        final streakData = snapshot.data ??
            const StreakData(
              days: 0,
              hours: 0,
              minutes: 0,
              seconds: 0,
              startTime: null,
            );

        final shouldShowButton =
            _treeService.shouldShowPlantTreeCTA(streakData.days, hours: streakData.hours, minutes: streakData.minutes) &&
                !_hasPlantedTree;

        if (!shouldShowButton) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          child: ElevatedButton(
            onPressed: _handlePlantTreePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
              minimumSize: const Size(200, 60),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.eco,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.translate('treeOfLife_plantTree'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'ElzaRound',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePlantTreePressed() {
    final l10n = AppLocalizations.of(context)!;
    // This handles the "Plant Tree" button press
    // The tree will automatically show proportional growth based on current streak
    MixpanelService.trackEvent('Tree of Life Screen: Plant Tree Button Tap');
    
    // Show confirmation message at top of screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.eco,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.translate('treeOfLife_treePlanted'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'ElzaRound',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          top: 50,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    
    // Mark tree as planted so button disappears forever (until streak resets)
    _saveTreePlantedState(true);
    
    // The tree widget will automatically update to show current progress
    // No additional action needed as it's connected to the streak stream
  }
} 