import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_reasons_to_quit.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/text_sanitizer.dart';
import 'package:stoppr/app/theme/colors.dart';

class ReasonToQuitWidget extends StatefulWidget {
  const ReasonToQuitWidget({super.key});

  @override
  State<ReasonToQuitWidget> createState() => _ReasonToQuitWidgetState();
}

class _ReasonToQuitWidgetState extends State<ReasonToQuitWidget> {
  String _reasonToQuit = '';
  
  @override
  void initState() {
    super.initState();
    _loadReasonToQuit();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadReasonToQuit();
  }

  Future<void> _loadReasonToQuit() async {
    final prefs = await SharedPreferences.getInstance();
    final reason = prefs.getString('reason_to_quit') ?? '';
    
    if (mounted) {
      setState(() {
        _reasonToQuit = reason;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Split the reason into lines and format each with quotes
    final List<String> reasonLines = _reasonToQuit.isEmpty 
        ? [] 
        : _reasonToQuit.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    return GestureDetector(
      onTap: () {
        // Track block tap with Mixpanel
        MixpanelService.trackButtonTap('Reason To Quit Block', screenName: 'Home Screen');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const HomeReasonsToQuitScreen(),
          ),
        ).then((_) => _loadReasonToQuit());
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(left: 20, right: 20, top: 30, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE0E0E0), // Light gray border
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('home_reasonToQuit_label'),
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray text for white background
                    fontSize: 12,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                const SizedBox(height: 8),
                if (reasonLines.isEmpty)
                  Text(
                    l10n.translate('home_reasonToQuit_placeholder'),
                    style: const TextStyle(
                      color: Color(0xFF999999), // Light gray for placeholder
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'ElzaRound Variable',
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: reasonLines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '"${TextSanitizer.sanitizeForDisplay(line.trim())}"',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A), // Dark text for white background
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'ElzaRound Variable',
                        ),
                      ),
                    )).toList(),
                  ),
              ],
            ),
          ),
          
          // Pen icon positioned at the top right
          Positioned(
            top: 20,
            right: 30,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFed3272), // Brand pink background
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE0E0E0), // Light gray border
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 