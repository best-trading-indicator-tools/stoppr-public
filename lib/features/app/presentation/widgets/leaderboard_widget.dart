// Edit (2025-09-16): Increase right padding on the current user CTA row
// to add breathing room between the trailing text and the rounded edge.
import 'package:flutter/material.dart';
import 'package:stoppr/core/models/leaderboard_entry.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class LeaderboardWidget extends StatelessWidget {
  final List<LeaderboardEntry> topEntries;
  final int currentUserRank;
  final int currentUserStreak;
  final String? currentUserId;
  // Branding/styling parameters with sensible defaults to preserve existing UI
  final Color backgroundColor;
  final Color textColor;
  final Color titleColor;
  final Color currentUserHighlightColor;
  final Color subtitleColor;
  final double verticalOffset;
  final bool showHeader;

  const LeaderboardWidget({
    super.key,
    required this.topEntries,
    required this.currentUserRank,
    required this.currentUserStreak,
    this.currentUserId,
    this.backgroundColor = const Color(0xFF1A022A),
    this.textColor = const Color(0xFFFFFFFF),
    this.titleColor = const Color(0xFFFFFFFF),
    this.currentUserHighlightColor = const Color(0xFF30DA7F),
    this.subtitleColor = const Color(0xFF90CAF9),
    this.verticalOffset = -60,
    this.showHeader = true,
  });

  // Fixed trailing width so streak column aligns across normal and CTA rows
  static const double _trailingWidth = 64;

  // Helper to format streak days
  String _formatStreak(int days) {
    // Use "days" for current user as in example, "d" otherwise
    return "${days}d"; 
  }

  String _formatCurrentUserStreak(int days) {
    return "$days days";
  }

  // Localize generic names like "User" or empty strings
  String _localizedName(AppLocalizations? l10n, String? rawName) {
    final String name = (rawName ?? '').trim();
    if (name.isEmpty) {
      return l10n!.translate('common_anonymous');
    }
    final lower = name.toLowerCase();
    if (lower == 'user' || lower == 'anonymous') {
      return l10n!.translate('common_anonymous');
    }
    return name;
  }

  // Colors for top positions
  // Use brand orange for top rank to ensure strong contrast on white
  static const Color goldColor = Color(0xFFfd5d32);
  static const Color silverColor = Color(0xFFC0C0C0);
  static const Color bronzeColor = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    // Base text style - now everything is bold and bigger
    final textStyle = TextStyle(
      color: textColor.withOpacity(0.9),
      fontSize: 19, // Increased from 17
      fontFamily: 'ElzaRound',
      fontWeight: FontWeight.bold, // All text is now bold by default
    );
    
    // Bold text style for elements that need emphasis
    final emphasisTextStyle = textStyle.copyWith(
      fontSize: 20, // Slightly larger for emphasis
    );

    // Determine if current user is already in topEntries
    final bool isUserLoggedIn = currentUserId != null;
    final bool userInTopEntries = isUserLoggedIn && topEntries.any((entry) => entry.userId == currentUserId);
    final bool shouldAddCurrentUserRowAtBottom = isUserLoggedIn && !userInTopEntries;

    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0), // Reduced top padding
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations!.translate('homeLearn_leaderboard'),
                      style: emphasisTextStyle.copyWith(fontSize: 22, color: titleColor), // Increased title size
                    ),
                    if (currentUserRank > 0)
                      Text(
                        localizations!.translate('homeLearn_leaderboardYouAreRank').replaceAll('{rank}', currentUserRank.toString()),
                        style: textStyle.copyWith(color: subtitleColor), 
                      )
                    // else - show nothing if rank is 0 or loading
                  ],
                ),
              ),

            // Leaderboard List
            if (topEntries.isEmpty && !shouldAddCurrentUserRowAtBottom) // Adjusted condition
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(localizations!.translate('homeLearn_leaderboardEmptyLoading'), style: textStyle),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true, // Important inside Column
                physics: const NeverScrollableScrollPhysics(), // Disable scrolling within the list
                itemCount: topEntries.length + (shouldAddCurrentUserRowAtBottom ? 1 : 0), // Use the new flag
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFFE0E0E0),
                  height: 1,
                  thickness: 1,
                ),
                itemBuilder: (context, index) {
                  String listItemEntryId;
                  String listItemName;
                  String listItemStreakDisplay;
                  String listItemRankDisplay;
                  int listItemRank;
                  // bool listItemIsCurrentUser; // No longer needed to pass this specific flag

                  if (index < topEntries.length) {
                    final entry = topEntries[index];
                    listItemEntryId = entry.userId;
                    listItemName = _localizedName(localizations, entry.name);
                    listItemStreakDisplay = _formatStreak(entry.streakDays);
                    listItemRank = entry.rank;
                    listItemRankDisplay = entry.medalEmoji ?? entry.rank.toString();
                    // listItemIsCurrentUser = isUserLoggedIn && entry.userId == currentUserId; // For _buildLeaderboardRow's internal logic
                  } else {
                    listItemEntryId = currentUserId!; // Known non-null due to shouldAddCurrentUserRowAtBottom
                    listItemName = localizations!.translate('homeLearn_leaderboardYouRowName');
                    listItemStreakDisplay = _formatCurrentUserStreak(currentUserStreak);
                    listItemRank = currentUserRank;
                    String? currentUserMedal;
                    if (currentUserRank == 1) currentUserMedal = '🥇';
                    else if (currentUserRank == 2) currentUserMedal = '🥈';
                    else if (currentUserRank == 3) currentUserMedal = '🥉';
                    listItemRankDisplay = currentUserMedal ?? currentUserRank.toString();
                    // listItemIsCurrentUser = true; // For _buildLeaderboardRow's internal logic
                  }

                  return _buildLeaderboardRow(
                    context,
                    rankDisplay: listItemRankDisplay,
                    name: listItemName,
                    streakDisplay: listItemStreakDisplay,
                    textStyle: textStyle,
                    emphasisTextStyle: emphasisTextStyle,
                    rank: listItemRank,
                    entryUserId: listItemEntryId,
                    currentUserId: currentUserId,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow(
    BuildContext context,
    {
      required String rankDisplay,
      required String name,
      required String streakDisplay,
      required TextStyle textStyle,
      required TextStyle emphasisTextStyle,
      // required bool isCurrentUser, // This parameter is no longer used directly for styling
      required int rank,
      required String entryUserId,
      String? currentUserId,
  }) {
    // Determine if this row is for the current logged-in user
    final bool isActuallyCurrentUserRow = currentUserId != null && entryUserId == currentUserId;

    // Determine name color based on rank
    Color? nameColor;
    if (rank == 1) {
      nameColor = goldColor;
    } else if (rank == 2) {
      nameColor = silverColor;
    } else if (rank == 3) {
      nameColor = bronzeColor;
    }

    // Define the style for the current user
    final currentUserTextStyle = textStyle.copyWith(color: currentUserHighlightColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 5.0),
      child: isActuallyCurrentUserRow
          ? Container(
              padding: const EdgeInsets.only(
                top: 10.0,
                bottom: 10.0,
                left: 8.0,
                right: 16.0,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      rankDisplay,
                      style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: _trailingWidth,
                    child: Text(
                      streakDisplay,
                      style: textStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    rankDisplay,
                    style: textStyle,
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: (rank <= 3 && nameColor != null)
                        ? textStyle.copyWith(color: nameColor)
                        : textStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: _trailingWidth,
                  child: Text(
                    streakDisplay,
                    style: textStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
    );
  }
} 