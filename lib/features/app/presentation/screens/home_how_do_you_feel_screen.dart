import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';

class HomeHowDoYouFeelScreen extends StatefulWidget {
  const HomeHowDoYouFeelScreen({super.key});

  @override
  State<HomeHowDoYouFeelScreen> createState() => _HomeHowDoYouFeelScreenState();
}

class _HomeHowDoYouFeelScreenState extends State<HomeHowDoYouFeelScreen> {
  String? _selectedEmoji;
  bool _isTempted = false;

  final List<Map<String, dynamic>> _emojis = [
    {'emoji': '😄', 'value': 'happy'},
    {'emoji': '😴', 'value': 'sleepy'},
    {'emoji': '😐', 'value': 'neutral'},
    {'emoji': '😟', 'value': 'worried'},
    {'emoji': '😢', 'value': 'sad'},
  ];

  @override
  void initState() {
    super.initState();
    
    // Force status bar icons to dark mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('How Do You Feel Screen',
      additionalProps: {'Source': 'Temptation Status'});
  }

  Future<void> _saveMoodAndTemptation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_mood_emoji', _selectedEmoji!);
    await prefs.setBool('is_tempted', _isTempted);
    
    // Print for debugging
    print('Saved temptation status: $_isTempted');

    if (mounted) {
      Navigator.of(context).pop();
    }
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
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8FA),
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.close,
              color: Color(0xFF1A1A1A),
              size: 30.0,
            ),
            onPressed: () {
              MixpanelService.trackButtonTap('Close', screenName: 'How Do You Feel Screen');
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Color(0xFF1A1A1A),
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const SizedBox(height: 40),
              Text(
                l10n.translate('howDoYouFeelScreen_title'),
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ElzaRound',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _emojis.map((emojiData) {
                    final bool isSelected = _selectedEmoji == emojiData['emoji'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = emojiData['emoji'];
                        });
                        MixpanelService.trackButtonTap('Emoji Selected', screenName: 'How Do You Feel Screen', 
                          additionalProps: {'Emoji': emojiData['emoji'], 'Value': emojiData['value']});
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected ? LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272),
                              Color(0xFFfd5d32),
                            ],
                          ) : null,
                          color: isSelected ? null : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            emojiData['emoji'],
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.translate('howDoYouFeelScreen_temptationQuestion'),
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Switch(
                      value: _isTempted,
                      onChanged: (value) {
                        setState(() {
                          _isTempted = value;
                        });
                        MixpanelService.trackButtonTap('Temptation Toggle', screenName: 'How Do You Feel Screen',
                          additionalProps: {'IsTempted': value});
                      },
                      activeColor: Color(0xFFed3272),
                      inactiveTrackColor: Color(0xFFE0E0E0),
                      inactiveThumbColor: Color(0xFF666666),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedEmoji == null ? null : () {
                  MixpanelService.trackButtonTap('Save Mood', screenName: 'How Do You Feel Screen');
                  _saveMoodAndTemptation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Color(0xFFE0E0E0),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ).copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _selectedEmoji == null ? null : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    color: _selectedEmoji == null ? Color(0xFFE0E0E0) : null,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      l10n.translate('common_save'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'ElzaRound',
                        color: _selectedEmoji == null ? Color(0xFF666666) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  MixpanelService.trackButtonTap('Dismiss', screenName: 'How Do You Feel Screen');
                  Navigator.of(context).pop();
                },
                child: Text(
                  l10n.translate('common_dismiss'),
                  style: TextStyle(
                    color: Color(0xFFed3272),
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ));
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'How Do You Feel Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }
} 