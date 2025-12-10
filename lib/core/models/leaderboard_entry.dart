/// Represents a single entry in the leaderboard.
class LeaderboardEntry {
  final String userId;
  final int rank;
  final String name;
  final int streakDays;
  final String? medalEmoji; // Nullable for ranks > 3

  LeaderboardEntry({
    required this.userId,
    required this.rank,
    required this.name,
    required this.streakDays,
    this.medalEmoji,
  });
} 