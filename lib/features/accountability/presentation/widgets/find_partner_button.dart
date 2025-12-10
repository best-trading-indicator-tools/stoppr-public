import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

/// CTA button for finding a random accountability partner
/// Shows gradient background with white text per brand guidelines
class FindPartnerButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final bool isInPool;

  const FindPartnerButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
    this.isInPool = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: isLoading || isInPool ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                ),
          color: isLoading ? Colors.white : null,
          border: isLoading 
              ? Border.all(color: const Color(0xFFE0E0E0), width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            if (!isLoading && !isInPool)
              BoxShadow(
                color: const Color(0xFFed3272).withOpacity(0.3),
                blurRadius: 12,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isInPool ? Icons.hourglass_empty : Icons.search,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isInPool
                          ? l10n.translate('accountability_finding_partner')
                          : l10n.translate('accountability_find_partner'),
                      style: const TextStyle(
                        color: Colors.white,
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

