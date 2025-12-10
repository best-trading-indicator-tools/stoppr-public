import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemUiOverlayStyle
import 'meditation_screen.dart'; // Import the new screen
import 'package:flutter/cupertino.dart'; // Import for CupertinoPageRoute
import 'package:stoppr/features/learn/presentation/screens/articles_list_screen.dart';
import 'package:stoppr/features/learn/presentation/screens/learn_video_list_screen.dart'; // Import the new video list screen
import 'podcast_screen.dart'; // Import the new Podcast screen
import 'package:stoppr/core/repositories/user_repository.dart'; // Use package import
import 'package:stoppr/core/models/leaderboard_entry.dart'; // Use package import
import 'package:stoppr/features/app/presentation/widgets/leaderboard_widget.dart'; // Use package import
import 'package:stoppr/core/analytics/mixpanel_service.dart'; // Import MixpanelService
import 'package:stoppr/core/localization/app_localizations.dart'; // Import AppLocalizations

class HomeLearnScreen extends StatefulWidget {
  const HomeLearnScreen({super.key});

  @override
  State<HomeLearnScreen> createState() => _HomeLearnScreenState();
}

class _HomeLearnScreenState extends State<HomeLearnScreen> {
  final UserRepository _userRepository = UserRepository();
  late Future<Map<String, dynamic>> _leaderboardDataFuture;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Get current user ID (can be null)
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Always initialize the future, pass potentially null userId
    _leaderboardDataFuture = _userRepository.getLeaderboardData(_currentUserId);
    print("Initializing leaderboard fetch for user: $_currentUserId"); 

    // Track page view with Mixpanel
    MixpanelService.trackPageView('Home Learn Screen');
  }

  @override
  Widget build(BuildContext context) {
    // Get the localization helper
    final localizations = AppLocalizations.of(context);
    
    // Set status bar icons to be visible with light color (white)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS uses opposite naming
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF140120), // Background color from image
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false, // Don't center the title
        leadingWidth: 0, // No leading width
        titleSpacing: 16.0, // Left padding
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // iOS uses opposite naming
        ),
        title: Row(
          children: [
            Text(
              localizations!.translate('homeLearn_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6), // small spacing between title and subtitle
            Expanded(
              child: Text(
                localizations.translate('homeLearn_subtitle'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView( // Make body scrollable
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0), // Reduce bottom padding
          child: Column( // Wrap content in a Column
            crossAxisAlignment: CrossAxisAlignment.start, // Align to left edge
            mainAxisSize: MainAxisSize.min, // Take minimum vertical space needed
            children: [
              GridView.count(
                shrinkWrap: true, // Important inside Column
                physics: const NeverScrollableScrollPhysics(), // Disable grid scrolling
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2, // Adjusted aspect ratio for less height
                children: [
                  _buildLearnOption(
                    context,
                    title: localizations.translate('homeLearn_articles'),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB74D), Color(0xFFFB8C00)], // Light Orange to Orange
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.article,
                    onTap: () {
                      // Track tap
                      MixpanelService.trackButtonTap('Articles', screenName: 'Home Learn Screen');
                      // Navigate to ArticlesListScreen
                      print('Articles tapped - Navigating...');
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const ArticlesListScreen()),
                      );
                    },
                  ),
                  _buildLearnOption(
                    context,
                    title: localizations.translate('homeLearn_meditate'),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)], // Deep Purple to Vibrant Purple
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.spa, // Consider sparkle icon like image: Icons.auto_awesome
                    onTap: () {
                      // Track tap
                      MixpanelService.trackButtonTap('Meditate', screenName: 'Home Learn Screen');
                      // Navigate to MeditationScreen
                      print('Meditate tapped - Navigating...');
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const MeditationScreen()),
                      );
                    },
                    iconWidget: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.7), size: 20),
                      ),
                    )
                  ),
                  _buildLearnOption(
                    context,
                    title: localizations.translate('homeLearn_learn'),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD81B60), Color(0xFFEC407A)], // Vibrant Pink to Lighter Pink
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.school, // Consider play icon: Icons.play_arrow
                    onTap: () {
                      // Track tap
                      MixpanelService.trackButtonTap('Learn Videos', screenName: 'Home Learn Screen');
                      print('Learn tapped');
                      // Navigate to LearnVideoListScreen
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const LearnVideoListScreen()),
                      );
                    },
                     iconWidget: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.play_arrow, color: Colors.white.withOpacity(0.9), size: 24),
                      ),
                    )
                  ),
                  _buildLearnOption(
                    context,
                    title: localizations.translate('homeLearn_podcast'),
                    // Blue gradient with subtle wave/circle pattern needed
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF42A5F5)], // Deep Blue to Standard Blue
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.podcasts,
                     onTap: () {
                      // Track tap
                      MixpanelService.trackButtonTap('Podcast', screenName: 'Home Learn Screen');
                      print('Podcast tapped');
                      // Navigate to PodcastScreen
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const PodcastScreen()), // Navigate to PodcastScreen
                    );},
                    // Add icon/pattern later if complex
                  ),
                ],
              ),

              // Leaderboard Section - Always show FutureBuilder
              FutureBuilder<Map<String, dynamic>>(
                future: _leaderboardDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Optional: Show a different loading state if desired
                    return const Center(child: CircularProgressIndicator(color: Colors.white54));
                  }
                  if (snapshot.hasError) {
                    print("Leaderboard Error: ${snapshot.error}");
                    // Keep error message generic
                    return Center(child: Text(AppLocalizations.of(context)!.translate('leaderboard_couldNotLoad'), style: TextStyle(color: Colors.white70)));
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    // Keep message generic
                    return Center(child: Text(AppLocalizations.of(context)!.translate('leaderboard_dataUnavailable'), style: TextStyle(color: Colors.white70)));
                  }

                  final data = snapshot.data!;
                  final List<LeaderboardEntry> topEntries = data['topEntries'];
                  final Map<String, dynamic> currentUserInfo = data['currentUserInfo'];
                  // Use defaults if user isn't logged in or data is missing
                  final int rank = currentUserInfo['rank'] ?? 0;
                  final int streak = currentUserInfo['streak'] ?? 0;

                  return LeaderboardWidget(
                    topEntries: topEntries,
                    currentUserRank: rank,
                    currentUserStreak: streak,
                    currentUserId: _currentUserId,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearnOption(
    BuildContext context,
    {
      required String title,
      required Gradient gradient,
      required IconData icon,
      Widget? iconWidget, // Accept an optional widget for icons/patterns
      required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack( // Use Stack to overlay iconWidget
          children: [
             // Place the iconWidget in the Stack
            if (iconWidget != null) iconWidget,
            Padding(
              padding: const EdgeInsets.all(16.0), // Keep padding for text
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 