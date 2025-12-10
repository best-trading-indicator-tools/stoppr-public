import 'package:flutter/material.dart';
import 'package:stoppr/features/accountability/data/models/partnership.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Dialog showing an incoming partnership request
/// Allows user to accept or decline the request
class PartnerRequestDialog extends StatelessWidget {
  final Partnership partnership;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const PartnerRequestDialog({
    super.key,
    required this.partnership,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Determine requester info
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isUser1 = partnership.user1Id == currentUserId;
    final requesterName = isUser1 ? partnership.user2Name : partnership.user1Name;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  _getInitial(requesterName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              l10n.translate('accountability_request_title')
                  .replaceAll('{name}', requesterName),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 22,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              l10n.translate('accountability_request_message'),
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 15,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Accept button (gradient CTA)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                onAccept();
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272),
                      Color(0xFFfd5d32),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    l10n.translate('accountability_request_accept'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Decline button (secondary)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDecline();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                l10n.translate('accountability_request_decline'),
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

