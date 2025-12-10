import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class CommunityRulesScreen extends StatelessWidget {
  const CommunityRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF0E001F); // App's primary dark color

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: primaryColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('communityRules_title'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable rules list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  children: [
                    _buildRuleItem('1', AppLocalizations.of(context)!.translate('communityRules_rule1')),
                    _buildRuleItem('2', AppLocalizations.of(context)!.translate('communityRules_rule2')),
                    _buildRuleItem('3', AppLocalizations.of(context)!.translate('communityRules_rule3')),
                    _buildRuleItem('4', AppLocalizations.of(context)!.translate('communityRules_rule4')),
                    _buildRuleItem('5', AppLocalizations.of(context)!.translate('communityRules_rule5')),
                    _buildRuleItem('6', AppLocalizations.of(context)!.translate('communityRules_rule6')),
                    _buildRuleItem('7', AppLocalizations.of(context)!.translate('communityRules_rule7')),
                    _buildRuleItem('8', AppLocalizations.of(context)!.translate('communityRules_rule8')),
                    _buildRuleItem('9', AppLocalizations.of(context)!.translate('communityRules_rule9')),
                    _buildRuleItem('10', AppLocalizations.of(context)!.translate('communityRules_rule10')),
                    _buildRuleItem('11', AppLocalizations.of(context)!.translate('communityRules_rule11')),
                    _buildRuleItem('12', AppLocalizations.of(context)!.translate('communityRules_rule12')),
                    _buildRuleItem('13', AppLocalizations.of(context)!.translate('communityRules_rule13')),
                    _buildRuleItem('14', AppLocalizations.of(context)!.translate('communityRules_rule14')),
                    // Add some padding at the bottom for better scrolling
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Sticky button positioned higher
              Container(
                margin: const EdgeInsets.only(bottom: 32.0),
                child: _buildJoinCommunityButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCommunityButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        onPressed: _openTelegramGroup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.translate('joinCommunity_button'),
          style: const TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF0E001F),
          ),
        ),
      ),
    );
  }

  void _openTelegramGroup() async {
    final Uri url = Uri.parse('https://t.me/+SKqx1P0D3iljZGRh');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open Telegram group');
    }
  }
} 