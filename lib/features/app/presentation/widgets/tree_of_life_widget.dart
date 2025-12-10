import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/tree/tree_of_life_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class TreeOfLifeWidget extends StatefulWidget {
  final bool showPlantButton;
  final VoidCallback? onPlantPressed;
  
  const TreeOfLifeWidget({
    super.key,
    this.showPlantButton = false,
    this.onPlantPressed,
  });

  @override
  State<TreeOfLifeWidget> createState() => _TreeOfLifeWidgetState();
}

class _TreeOfLifeWidgetState extends State<TreeOfLifeWidget>
    with TickerProviderStateMixin {
  final StreakService _streakService = StreakService();
  final TreeOfLifeService _treeService = TreeOfLifeService();
  
  late AnimationController _treeAnimationController;
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;
  
  bool _hasPlantedTree = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tree animation controller
    _treeAnimationController = AnimationController(vsync: this);
    
    // Initialize fade in controller for smooth transitions
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeInOut,
    ));
    
    _loadTreePlantedState();
    _fadeInController.forward();
    
    // Track page view
    MixpanelService.trackPageView('Tree of Life');
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
    _treeAnimationController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
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
        
        final streakDays = streakData.days;
        
        // IMPORTANT: Reset planted state immediately if streak is back to 0
        // This must happen BEFORE calculating shouldShowPlantButton
        if (streakDays == 0 && _hasPlantedTree) {
          // Streak reset - immediately reset planted state
          _saveTreePlantedState(false);
        }
        
        // Show plant button only if: widget allows it, no progress at all, AND tree hasn't been planted yet
        final shouldShowPlantButton = widget.showPlantButton && 
                                    _treeService.shouldShowPlantTreeCTA(streakDays, hours: streakData.hours, minutes: streakData.minutes) &&
                                    !_hasPlantedTree;
        final treeProgress = _treeService.calculateTreeProgress(streakDays, hasPlantedTree: _hasPlantedTree, hours: streakData.hours, minutes: streakData.minutes);
        final growthStage = _treeService.getGrowthStage(streakDays);
        

        
        return FadeTransition(
          opacity: _fadeInAnimation,
          child: Container(
            width: double.infinity,
            height: 400,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Tree animation
                if (!shouldShowPlantButton)
                  _buildTreeAnimation(treeProgress),
                
                // Plant tree button (only shows on day 1 or if no progress)
                if (shouldShowPlantButton)
                  _buildPlantTreeButton(l10n),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTreeAnimation(double progress) {
    return Container(
      width: 320,
      height: 350,
      child: Lottie.asset(
        'assets/images/lotties/BlossomTree.json',
        controller: _treeAnimationController,
        onLoaded: (composition) {
          // Set animation duration and animate from start to current progress
          _treeAnimationController.duration = composition.duration;
          _treeAnimationController.reset(); // Start from beginning
          _treeAnimationController.animateTo(
            progress,
            duration: const Duration(milliseconds: 2000), // 2 second growth animation
            curve: Curves.easeInOut,
          );
        },
        fit: BoxFit.contain,
        animate: false, // We control animation manually via progress
      ),
    );
  }
  
  Widget _buildPlantTreeButton(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Plant icon or small tree illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.eco,
              size: 60,
              color: Colors.green,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Plant tree button
          ElevatedButton(
            onPressed: () async {
              MixpanelService.trackButtonTap(
                'Plant Tree',
                screenName: 'Tree of Life',
              );
              // Mark tree as planted so button disappears forever (until streak resets)
              await _saveTreePlantedState(true);
              
              // Force immediate rebuild to show tree
              if (mounted) {
                setState(() {
                  // This will trigger an immediate rebuild
                });
              }
              
              if (widget.onPlantPressed != null) {
                widget.onPlantPressed!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 8,
            ),
            child: Text(
              l10n.translate('treeOfLife_plantTree'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Motivation text with better contrast
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              l10n.translate('treeOfLife_plantMotivation'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGrowthStageIndicator(
    AppLocalizations l10n,
    TreeGrowthStage stage,
    int streakDays,
  ) {
    final stageKey = _treeService.getGrowthStageKey(stage);
    final nextMilestone = _treeService.getNextMilestone(streakDays);
    final daysToMilestone = nextMilestone - streakDays;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main days counter
          Text(
            '$streakDays',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              fontFamily: 'ElzaRound',
            ),
          ),
          
          Text(
            l10n.translate('treeOfLife_days'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontFamily: 'ElzaRound',
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Growth stage
          Text(
            l10n.translate(stageKey),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'ElzaRound',
            ),
          ),
          
          if (daysToMilestone > 0) ...[
            const SizedBox(height: 4),
            Text(
              l10n.translate('treeOfLife_daysToMilestone')
                  .replaceAll('{days}', daysToMilestone.toString()),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'ElzaRound',
              ),
            ),
          ],
        ],
      ),
    );
  }
} 