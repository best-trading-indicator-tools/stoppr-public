import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/streak/achievements_service.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/features/accountability/data/models/partnership.dart';
import 'package:stoppr/features/accountability/data/repositories/accountability_repository.dart';

/// Widget displaying all available partners in a grid with tap-to-select
class AvailablePartnersList extends StatefulWidget {
  final VoidCallback onRandomPartnerTap;
  final Function(PoolEntry) onPartnerSelect;
  final List<Partnership> outgoingPendingRequests;

  const AvailablePartnersList({
    super.key,
    required this.onRandomPartnerTap,
    required this.onPartnerSelect,
    this.outgoingPendingRequests = const [],
  });

  @override
  State<AvailablePartnersList> createState() => _AvailablePartnersListState();
}

class _AvailablePartnersListState extends State<AvailablePartnersList> {
  final AccountabilityRepository _repository = AccountabilityRepository();
  final TextEditingController _searchController = TextEditingController();
  List<PoolEntry> _partners = [];
  List<PoolEntry> _filteredPartners = [];
  bool _isLoading = true;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    _loadAvailablePartners();
    
    // Listen to search text changes for UI updates
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _hasSearchText = _searchController.text.isNotEmpty;
        });
        _filterPartners(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _achievementAssetForDays(int days) {
    // Pick the highest achievement whose daysRequired <= days
    final achievements = AchievementsService.availableAchievements;
    achievements.sort((a, b) => a.daysRequired.compareTo(b.daysRequired));
    String asset = achievements.first.imageAsset; // default to the smallest
    for (final a in achievements) {
      if (days >= a.daysRequired) {
        asset = a.imageAsset;
      } else {
        break;
      }
    }
    return asset;
  }

  Future<void> _loadAvailablePartners() async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch users from pool (high limit since we filter by subscription now)
      var poolSnapshot = await _repository.getPoolUsers(limit: 200);
      
      // Always fetch fallback to ensure we show all subscribers
      // (Since we now filter by active subscription, pool may have stale entries)
      final fallback = await _repository.getFallbackAvailableUsers(limit: 200);
      
      // Merge unique users by userId
      final seen = <String>{...poolSnapshot.map((e) => e.userId)};
      for (final u in fallback) {
        if (!seen.contains(u.userId)) {
          poolSnapshot.add(u);
          seen.add(u.userId);
        }
      }
      
      // Filter out users who already have pending requests from current user
      final pendingUserIds = <String>{};
      for (final request in widget.outgoingPendingRequests) {
        // Add the recipient's userId (the one who didn't initiate)
        pendingUserIds.add(request.user2Id);
      }
      
      final availablePartners = poolSnapshot
          .where((partner) => !pendingUserIds.contains(partner.userId))
          .toList();
      
      // Sort by streak (lowest first) - prioritize users who need the most help
      availablePartners.sort((a, b) => a.currentStreak.compareTo(b.currentStreak));
      
      debugPrint('Loaded ${availablePartners.length} available partners (filtered ${pendingUserIds.length} with pending requests)');
      
      // Log first 20 users with their userIds for verification
      final displayCount = availablePartners.length < 20 ? availablePartners.length : 20;
      debugPrint('📋 First $displayCount partners to display:');
      for (int i = 0; i < displayCount; i++) {
        final p = availablePartners[i];
        debugPrint('   ${i + 1}. ${p.firstName} (userId: ${p.userId.substring(0, 8)}, streak: ${p.currentStreak})');
      }
      
      if (!mounted) return;
      setState(() {
        _partners = availablePartners;
        _filteredPartners = availablePartners;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading available partners: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _filterPartners(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredPartners = _partners;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredPartners = _partners
          .where((partner) =>
              partner.firstName.toLowerCase().contains(lowerQuery))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Random partner button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _buildRandomPartnerButton(l10n),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildSearchField(l10n),
        ),

        // Available partners section header
        if (!_isLoading && _filteredPartners.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.translate('accountability_available_partners'),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 18,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              l10n.translate('accountability_available_partners_subtitle'),
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],

        // Available partners grid or loading
        if (_isLoading)
          _buildLoadingState()
        else if (_filteredPartners.isEmpty)
          _buildEmptyState(l10n)
        else
          _buildPartnersGrid(),
      ],
    );
  }

  Widget _buildRandomPartnerButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: widget.onRandomPartnerTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFed3272).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shuffle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.translate('accountability_find_partner'),
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
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      style: const TextStyle(
        fontFamily: 'ElzaRound',
        fontSize: 16,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: l10n.translate('accountability_search_partners'),
        hintStyle: const TextStyle(
          fontFamily: 'ElzaRound',
          fontSize: 16,
          color: Color(0xFF666666),
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF666666),
          size: 22,
        ),
        suffixIcon: _hasSearchText
            ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF666666),
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFed3272),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      textInputAction: TextInputAction.search,
      keyboardType: TextInputType.text,
    );
  }

  Widget _buildPartnersGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredPartners.length,
        itemBuilder: (context, index) {
          return _buildPartnerCard(_filteredPartners[index]);
        },
      ),
    );
  }

  Widget _buildPartnerCard(PoolEntry partner) {
    return GestureDetector(
      onTap: () => widget.onPartnerSelect(partner),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Achievement lottie
              SizedBox(
                width: 48,
                height: 48,
                child: Lottie.asset(
                  _achievementAssetForDays(partner.currentStreak),
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
              const SizedBox(height: 4),
              
              // First name
              Text(
                partner.firstName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'ElzaRound',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              
              // Streak with mini achievement lottie (strictly constrained)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: Lottie.asset(
                      _achievementAssetForDays(partner.currentStreak),
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${partner.currentStreak}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFed3272),
                      fontFamily: 'ElzaRound',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final message = _hasSearchText
        ? l10n.translate('accountability_no_search_results')
        : l10n.translate('accountability_no_partners_available');
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF666666),
          fontFamily: 'ElzaRound',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
