import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_scaffold.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';

class HomeSuccessStoriesScreen extends StatefulWidget {
  const HomeSuccessStoriesScreen({super.key});

  @override
  State<HomeSuccessStoriesScreen> createState() => _HomeSuccessStoriesScreenState();
}

class _HomeSuccessStoriesScreenState extends State<HomeSuccessStoriesScreen> {
  late List<SuccessStory> _localizedSuccessStories;

  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Success Stories Screen');
    
    // Force status bar icons to dark mode for light backgrounds
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }
  
  @override
  void dispose() {
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _localizedSuccessStories = List.generate(20, (i) => SuccessStory(
      nameKey: 'successStory${i+1}_name',
      locationKey: 'successStory${i+1}_location',
      age: _getOriginalStoryData(i+1)['age'] as int,
      days: _getOriginalStoryData(i+1)['days'] as int,
      storyKey: 'successStory${i+1}_story',
    ));
  }

  Map<String, dynamic> _getOriginalStoryData(int storyNum) {
    final originalStoriesData = [
      {'age': 32, 'days': 3}, {'age': 45, 'days': 5}, {'age': 29, 'days': 1}, {'age': 37, 'days': 7}, {'age': 41, 'days': 10},
      {'age': 33, 'days': 2}, {'age': 38, 'days': 14}, {'age': 52, 'days': 21}, {'age': 26, 'days': 1}, {'age': 44, 'days': 8},
      {'age': 30, 'days': 4}, {'age': 35, 'days': 6}, {'age': 48, 'days': 12}, {'age': 31, 'days': 2}, {'age': 27, 'days': 5},
      {'age': 40, 'days': 9}, {'age': 34, 'days': 7}, {'age': 39, 'days': 15}, {'age': 43, 'days': 3}, {'age': 36, 'days': 4},
    ];
    return originalStoriesData[storyNum-1];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFFDF8FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                TopToBottomPageRoute(
                  child: const MainScaffold(initialIndex: 0),
                  settings: const RouteSettings(name: '/home'),
                ),
              );
            },
          ),
          title: Text(
            l10n.translate('successStoriesScreen_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'ElzaRound',
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: _localizedSuccessStories.length,
            itemBuilder: (context, index) {
              final story = _localizedSuccessStories[index];
              return SuccessStoryCard(story: story);
            },
          ),
        ),
      ),
    );
  }
}

class SuccessStory {
  final String nameKey;
  final int age;
  final String locationKey;
  final int days;
  final String storyKey;

  SuccessStory({
    required this.nameKey,
    required this.age,
    required this.locationKey,
    required this.days,
    required this.storyKey,
  });
}

class SuccessStoryCard extends StatelessWidget {
  final SuccessStory story;

  const SuccessStoryCard({
    super.key,
    required this.story,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFed3272).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name, age, location
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Name, age, location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate(story.nameKey),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'ElzaRound',
                        ),
                      ),
                      Text(
                        '${story.age} • ${l10n.translate(story.locationKey)}',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          fontFamily: 'ElzaRound',
                        ),
                      ),
                    ],
                  ),
                ),
                // Days sugar-free badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${story.days}${l10n.translate('successStoriesScreen_daysBadgeSuffix')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Story content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.translate(story.storyKey),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 15,
                height: 1.4,
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
        ],
      ),
    );
  }
} 