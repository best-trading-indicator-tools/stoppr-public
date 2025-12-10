import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:stoppr/core/analytics/mixpanel_service.dart'; // Import MixpanelService
import 'package:stoppr/core/localization/app_localizations.dart'; // Import localization
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/features/learn/domain/models/learn_video_lesson.dart';
import 'package:stoppr/features/learn/presentation/cubit/learn_video_cubit.dart';
import '../widgets/learn_video_list_item_widget.dart'; // Now using the actual widget
import 'package:stoppr/features/learn/presentation/screens/full_screen_video_player_screen.dart';
import '../widgets/learn_info_bottom_sheet_widget.dart'; // Added import
import 'package:flutter_svg/flutter_svg.dart'; // Added for popup icon
import 'package:video_player/video_player.dart'; // For background video preloading
import '../../../../../core/usage/feature_quota_service.dart'; // Add quota service
import '../../../../core/services/video_player_defensive_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart'; // Add Superwall import
import 'package:flutter/foundation.dart'; // Import for kDebugMode

class LearnVideoListScreen extends StatelessWidget {
  const LearnVideoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = LearnVideoCubit();
        //cubit.resetProgress(); // <--- TEMPORARILY UNCOMMENT THIS LINE FOR TESTING
        cubit.loadLessons();
        return cubit;
      },
      child: const _LearnVideoListView(),
    );
  }
}

class _LearnVideoListView extends StatefulWidget {
  const _LearnVideoListView();

  @override
  State<_LearnVideoListView> createState() => _LearnVideoListViewState();
}

class _LearnVideoListViewState extends State<_LearnVideoListView> {
  VideoPlayerController? _preloadController;
  bool _hasPreloaded = false;
  final _quotaService = FeatureQuotaService(); // Add quota service
  bool _isNavigating = false; // Add navigation guard flag

  @override
  void initState() {
    super.initState();
    // Track page view when the screen is initialized
    MixpanelService.trackPageView('Page View: Learn Video List Screen');
  }

  void _handleLessonTap(BuildContext context, LearnVideoLesson lesson) async {
    // Prevent double-tap navigation
    if (_isNavigating) {
      debugPrint('Navigation already in progress, ignoring tap');
      return;
    }

    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system

    final String popupTitle = AppLocalizations.of(context)!.translate('learnVideoList_lockedLessonTitle');
    final String popupMessage = AppLocalizations.of(context)!.translate('learnVideoList_lockedLessonMessage');
    const TextStyle popupTitleStyle = TextStyle(
      fontFamily: 'ElzaRound',
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A1A), // Brand primary text color
      fontSize: 22, // Default size, adjust if needed
    );
    final Widget popupIcon = Image.asset(
      'assets/images/learn/listen_lessons_order_popup.png', // New shared icon
      width: 64, 
      height: 64, 
    );

    if (lesson.isLocked) {
      showLearnInfoBottomSheet(
        context,
        icon: popupIcon,
        title: popupTitle,
        titleTextStyle: popupTitleStyle,
        message: popupMessage,
        primaryButtonText: AppLocalizations.of(context)!.translate('learnVideoList_dismiss'),
        onPrimaryButtonPressed: () {
          // Track dismiss button tap for locked lesson
          MixpanelService.trackButtonTap(
            'Learn: Dismiss Locked Lesson Popup',
            screenName: 'LearnVideoListScreen',
            additionalProps: {'lesson_id': lesson.id, 'lesson_title': lesson.title},
          );
          Navigator.pop(context);
        },
      );
    } else {
      // Set navigation guard
      setState(() {
        _isNavigating = true;
      });
      
      // Add quota check for lesson 2+ (DISABLED for A/B test)
      if (QUOTA_SYSTEM_ENABLED && lesson.id != "lesson_1") {
        final canUse = await _quotaService.canUseLearnVideo();
        if (!canUse) {
          MixpanelService.trackButtonTap('Learn Video Quota Exceeded Paywall Shown');
          await _showStandardPaywall();
          // Reset navigation guard
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
          return;
        }
      }
      
      // Lesson is unlocked; navigate directly to the player.
      // Track unlocked lesson tap with clear event name
      MixpanelService.trackEvent(
        'Learn ${lesson.title} tapped',
        properties: {'lesson_id': lesson.id, 'lesson_title': lesson.title},
      );
      
      // Record usage for lesson 1 only (DISABLED for A/B test)
      if (QUOTA_SYSTEM_ENABLED && lesson.id == "lesson_1") {
        await _quotaService.recordLearnVideoUse();
      }
      
      _navigateToPlayer(context, lesson);
    }
  }

  void _navigateToPlayer(BuildContext context, LearnVideoLesson lesson) {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: BlocProvider.of<LearnVideoCubit>(context),
          child: FullScreenVideoPlayerScreen(lesson: lesson),
        ),
      ),
    ).then((_) {
      // Reset navigation guard when returning
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
      // context.read<LearnVideoCubit>().loadLessons(); 
    });
  }

  Future<void> _preloadNextLesson(List<LearnVideoLesson> lessons) async {
    LearnVideoLesson? nextLessonToPreload;

    if (lessons.isEmpty) {
      nextLessonToPreload = null;
    } else {
      try {
        // Try to find the first uncompleted and unlocked lesson
        nextLessonToPreload = lessons.firstWhere((l) => !l.isCompleted && !l.isLocked);
      } catch (e) {
        // If no such lesson is found (StateError from firstWhere because no orElse was provided),
        // fallback to the last lesson in the list.
        nextLessonToPreload = lessons.last;
      }
    }

    if (nextLessonToPreload == null) {
      // This case implies lessons was empty.
      // Dispose any existing controller and clear it.
      await _preloadController?.dispose();
      _preloadController = null;
      return;
    }

    // Proceed with preloading using nextLessonToPreload
    try {
      _preloadController = await VideoPlayerDefensiveService.initializeWithDefensiveMeasures(
        videoPath: nextLessonToPreload.videoAssetPath,
        isNetworkUrl: nextLessonToPreload.videoAssetPath.startsWith('http'),
        formatHint: nextLessonToPreload.videoAssetPath.startsWith('http') ? VideoFormat.hls : null,
        context: 'LearnVideoListScreen-Preload',
      );
      await _preloadController!.setVolume(0.0); // Ensure nothing plays or makes sound
      await _preloadController!.pause();
    } catch (e) {
      // Silently fail – preloading is a best-effort optimisation.
      // Log error for debugging if needed: print("Preload failed: $e");
      await _preloadController?.dispose(); // Clean up if initialization failed
      _preloadController = null;
    } finally {
      // Dispose immediately after initialization (or failure) to free decoder resources.
      // The OS network stack will have cached the manifest/initial segments.
      await _preloadController?.dispose();
      _preloadController = null;
    }
  }

  @override
  void dispose() {
    _preloadController?.dispose();
    super.dispose();
  }

  // Method to show paywall when quota exceeded
  Future<void> _showStandardPaywall() async {
    try {
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        debugPrint("Learn Video Paywall presented: ${name ?? 'Unknown'}");
        MixpanelService.trackEvent('Learn Video Quota Paywall Presented', 
          properties: {'paywall_name': name ?? 'Unknown'}
        );
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        debugPrint("Learn Video Paywall dismissed: ${name ?? 'Unknown'}, Result: $paywallResult");
        MixpanelService.trackEvent('Learn Video Quota Paywall Dismissed', 
          properties: {
            'paywall_name': name ?? 'Unknown',
            'result': paywallResult?.toString() ?? 'null'
          }
        );
      });

      handler.onError((error) {
        debugPrint("Learn Video Paywall error: $error");
        MixpanelService.trackEvent('Learn Video Quota Paywall Error', 
          properties: {'error': error.toString()}
        );
      });

      handler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        debugPrint("Learn Video Paywall skipped: $reasonString");
        MixpanelService.trackEvent('Learn Video Quota Paywall Skipped', 
          properties: {'reason': reasonString}
        );
      });

      // Register the placement with handlers
      await Superwall.shared.registerPlacement(
        'INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE',
        handler: handler,
        feature: () async {
          // Reset quotas on successful purchase
          await _quotaService.resetAllQuotas();
          debugPrint('Learn Video: Quotas reset after successful purchase');
        },
      );
    } catch (e) {
      debugPrint('Error showing Learn Video paywall: $e');
    }
  }

  // DEBUG ONLY: Reset all quotas AND learn video completion data for testing
  Future<void> _debugResetQuotas() async {
    if (!kDebugMode) return;
    
    try {
      // Reset feature quotas
      await _quotaService.debugResetAllQuotas();
      
      // Reset learn video completion data (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('completed_learn_video_lessons');
      debugPrint('🔄 DEBUG: Cleared learn video completion data from SharedPreferences');
      
      // Reset learn video cubit state to reload lessons with fresh completion status
      if (mounted) {
        context.read<LearnVideoCubit>().resetProgress();
        debugPrint('🔄 DEBUG: Reset LearnVideoCubit progress state');
      }
      
      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 DEBUG: All quotas & learn video progress reset! You can test features again.',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'ElzaRound',
              ),
            ),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resetting quotas and learn data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to reset data: $e',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'ElzaRound',
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); // Get theme for progress indicator color
    return Scaffold(
      backgroundColor: Colors.white, // Changed to white background
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.translate('learnVideoList_title'),
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            height: 1.15,
            letterSpacing: -0.01,
            color: Color(0xFF1A1A1A), // Brand primary text color
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white, // Changed to white AppBar
        elevation: 0, // Keep elevation 0 for a flat look if desired, or add a slight shadow
        iconTheme: const IconThemeData(color: Colors.black87), // Ensure back/menu icons are dark
        systemOverlayStyle: SystemUiOverlayStyle.dark, // For status bar icons to be dark
        centerTitle: false,
        actions: [
          // Debug quota reset button
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF4CAF50), // Green color for reset
                  size: 24,
                ),
                tooltip: 'DEBUG: Reset All Quotas',
                onPressed: _debugResetQuotas,
              ),
            ),
        ],
      ),
      body: BlocBuilder<LearnVideoCubit, LearnVideoState>(
        builder: (context, state) {
          return state.when(
            initial: () => Center(
              child: Text(AppLocalizations.of(context)!.translate('learnVideoList_initializing'), style: TextStyle(color: Color(0xFF666666))), // Brand secondary text color
            ),
            loading: () => Center(child: CircularProgressIndicator(color: theme.primaryColor)), // Use theme color
            loaded: (lessons, showComingSoonMessageValue, error) {
              if (!_hasPreloaded) {
                _hasPreloaded = true;
                // Kick off background preload; no need to await.
                _preloadNextLesson(lessons);
              }
              if (error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText.rich(
                      TextSpan(
                        text: AppLocalizations.of(context)!.translate('learnVideoList_errorLoading').replaceFirst('{error}', error.toString()),
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ),
                );
              }
              if (lessons.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!.translate('learnVideoList_noLessons'),
                    style: TextStyle(color: Color(0xFF666666)), // Brand secondary text color
                  ),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...List.generate(
                      lessons.length,
                      (index) {
                        final isLast = index == lessons.length - 1;
                        final nextCompleted = !isLast && lessons[index + 1].isCompleted;
                        final isFirst = index == 0;
                        final prevCompleted = index > 0 && lessons[index - 1].isCompleted;
                        return Column(
                          children: [
                            LearnVideoListItemWidget(
                              lesson: lessons[index],
                              isLastItem: isLast,
                              nextLessonIsCompleted: nextCompleted,
                              isFirstItem: isFirst,
                              prevLessonIsCompleted: prevCompleted,
                              onTap: () => _handleLessonTap(context, lessons[index]),
                            ),
                          ],
                        );
                      },
                    ),
                    if (showComingSoonMessageValue)
                      _ComingSoonMessageWidget(),
                    const SizedBox(height: 120), // Increased space for better scroll-past protection
                  ],
                ),
              );
            },
            error: (message) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText.rich(
                  TextSpan(
                    text: AppLocalizations.of(context)!.translate('learnVideoList_error').replaceFirst('{message}', message),
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComingSoonMessageWidget extends StatelessWidget {
  _ComingSoonMessageWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              "❝",
              style: TextStyle(
                color: Color(0xFF666666).withOpacity(0.7), // Brand secondary text color
                fontSize: 36,
              ),
            ),
          ),
          Text(
            AppLocalizations.of(context)!.translate('learnVideoList_comingSoonMessage'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Brand primary text color
              fontSize: 16,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
} 