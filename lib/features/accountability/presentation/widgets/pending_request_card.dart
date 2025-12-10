import 'package:flutter/material.dart';
import 'package:stoppr/features/accountability/data/models/partnership.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Card widget displaying a pending partnership request
/// Shows requester info and accept/decline buttons
class PendingRequestCard extends StatelessWidget {
  final Partnership partnership;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isLoading;

  const PendingRequestCard({
    super.key,
    required this.partnership,
    required this.onAccept,
    required this.onDecline,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Determine which user sent the request
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isUser1 = partnership.user1Id == currentUserId;
    final requesterName = isUser1 ? partnership.user2Name : partnership.user1Name;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and name
          Row(
            children: [
              // Initial circle
              Container(
                width: 48,
                height: 48,
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
                      fontSize: 20,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Name and request text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterName,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 17,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.translate('accountability_wants_to_partner'),
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Accept and Decline buttons
          Row(
            children: [
              // Accept button with gradient
              Expanded(
                child: GestureDetector(
                  onTap: isLoading ? null : onAccept,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isLoading
                            ? [
                                const Color(0xFFed3272).withOpacity(0.5),
                                const Color(0xFFfd5d32).withOpacity(0.5),
                              ]
                            : [
                                const Color(0xFFed3272),
                                const Color(0xFFfd5d32),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              l10n.translate('accountability_accept_request'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Decline button
              Expanded(
                child: TextButton(
                  onPressed: isLoading ? null : onDecline,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.translate('accountability_decline_request'),
                    style: TextStyle(
                      color: isLoading
                          ? const Color(0xFF666666).withOpacity(0.3)
                          : const Color(0xFF666666),
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

