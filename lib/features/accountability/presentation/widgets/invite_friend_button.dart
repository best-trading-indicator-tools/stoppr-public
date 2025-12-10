import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

/// CTA button for inviting a friend to be accountability partner
/// Shows white background with gradient text and loading state
class InviteFriendButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const InviteFriendButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFed3272),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add,
                      color: Color(0xFFed3272),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.translate('accountability_invite_friend'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 19,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

