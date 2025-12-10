import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_scaffold.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';

class HomeReasonsToQuitScreen extends StatefulWidget {
  const HomeReasonsToQuitScreen({super.key});

  @override
  State<HomeReasonsToQuitScreen> createState() => _HomeReasonsToQuitScreenState();
}

class _HomeReasonsToQuitScreenState extends State<HomeReasonsToQuitScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    
    // Force status bar icons to dark mode with stronger settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Add listener to text controller to update UI when text changes
    _reasonController.addListener(() {
      setState(() {
        // This will trigger a rebuild for the suffixIcon
      });
    });
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Reasons To Quit Screen', 
      additionalProps: {'Source': 'Home Screen'});
    
    // Load existing reason
    _loadSavedReason();
  }
  
  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedReason() async {
    final prefs = await SharedPreferences.getInstance();
    final savedReason = prefs.getString('reason_to_quit');
    
    if (savedReason != null && mounted) {
      setState(() {
        _reasonController.text = savedReason;
        _hasText = savedReason.isNotEmpty;
      });
    }
  }

  Future<void> _saveReason() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reason_to_quit', _reasonController.text);
    
    // Track the save action with Mixpanel
    MixpanelService.trackEvent('Reasons To Quit - Saved', properties: {
      'HasReasons': _reasonController.text.isNotEmpty,
      'ReasonLength': _reasonController.text.length,
      'LineCount': _reasonController.text.isEmpty ? 0 : _reasonController.text.split('\n').where((line) => line.trim().isNotEmpty).length,
    });
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MainScaffold.createRoute(
          initialIndex: 0,
        ),
      );
    }
  }

  // Method to dismiss keyboard
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Reasons To Quit Screen');
    
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light, // iOS uses opposite naming
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: Scaffold(
          backgroundColor: const Color(0xFFFDF8FA),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light, // iOS uses opposite naming
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
              onPressed: () => Navigator.of(context).pushReplacement(
                MainScaffold.createRoute(
                  initialIndex: 0,
                ),
              ),
            ),
            actions: [
              // Help & Info icon
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
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      l10n.translate('reasonsToQuitScreen_title'),
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'ElzaRound',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.translate('reasonsToQuitScreen_description'),
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                      ),
                      textAlign: TextAlign.center,
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
                      child: Stack(
                        children: [
                          TextField(
                            controller: _reasonController,
                            maxLines: 10,
                            maxLength: 500,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                            ),
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: l10n.translate('reasonsToQuitScreen_textFieldHint'),
                              hintStyle: TextStyle(
                                color: Color(0xFF666666).withOpacity(0.6),
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                              ),
                              border: InputBorder.none,
                              counter: const SizedBox.shrink(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _hasText = value.isNotEmpty;
                              });
                            },
                          ),
                          if (_reasonController.text.isNotEmpty)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: Icon(Icons.clear, color: Color(0xFF666666).withOpacity(0.7)),
                                onPressed: () {
                                  MixpanelService.trackButtonTap('Clear Text', screenName: 'Reasons To Quit Screen');
                                  setState(() {
                                    _reasonController.clear();
                                    _hasText = false;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.translate('reasonsToQuitScreen_tipClearReasons'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF666666).withOpacity(0.7),
                        fontSize: 12,
                        fontFamily: 'ElzaRound',
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        MixpanelService.trackButtonTap('Save', screenName: 'Reasons To Quit Screen');
                        _saveReason();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
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
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272),
                              Color(0xFFfd5d32),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            l10n.translate('common_save'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        MixpanelService.trackButtonTap('Dismiss', screenName: 'Reasons To Quit Screen');
                        Navigator.of(context).pushReplacement(
                          MainScaffold.createRoute(
                            initialIndex: 0,
                          ),
                        );
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
          ),
        ),
      ),
    );
  }
} 