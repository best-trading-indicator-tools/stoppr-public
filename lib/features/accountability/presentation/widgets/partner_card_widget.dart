import 'package:flutter/material.dart';
import 'package:stoppr/features/accountability/data/models/accountability_partner.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Widget displaying current accountability partner information
/// Shows partner's name, streak, and last active time
class PartnerCardWidget extends StatelessWidget {
  final AccountabilityPartner partner;
  final VoidCallback onUnpair;

  const PartnerCardWidget({
    super.key,
    required this.partner,
    required this.onUnpair,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Label
          Text(
            l10n.translate('accountability_current_partner'),
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Profile circle with initial
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFed3272),
                  Color(0xFFfd5d32),
                ],
              ),
            ),
            child: Center(
              child: Text(
                _getInitial(partner.partnerFirstName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Partner name
          Text(
            partner.partnerFirstName ?? l10n.translate('accountability_partner'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 24,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Streak count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Color(0xFFed3272),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.translate('accountability_partner_streak')
                    .replaceAll('{count}', partner.partnerStreak.toString()),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Last synced/active time
          if (partner.lastSyncedAt != null)
            Text(
              '${l10n.translate('accountability_last_active')} ${_getTimeAgo(partner.lastSyncedAt!, context)}',
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 13,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 20),

          // Unpair button
          TextButton(
            onPressed: onUnpair,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Colors.grey.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.translate('accountability_unpair'),
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 15,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  String _getTimeAgo(DateTime dateTime, BuildContext context) {
    // Set locale for timeago based on app locale
    final locale = AppLocalizations.of(context)!.locale.languageCode;
    return timeago.format(dateTime, locale: locale);
  }
}

