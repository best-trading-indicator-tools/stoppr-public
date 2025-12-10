import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/core/models/leaderboard_entry.dart';
import 'package:stoppr/features/app/presentation/widgets/leaderboard_widget.dart';

/// Simple screen that shows the global no-sugar streak leaderboard
/// using brand colors and full localization.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final UserRepository _userRepository = UserRepository();
  late Future<Map<String, dynamic>> _leaderboardDataFuture;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _leaderboardDataFuture = _userRepository.getLeaderboardData(_currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainScaffold(initialIndex: 0),
              ),
            );
          },
        ),
        title: Text(
          l10n.translate('homeLearn_leaderboard'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 22,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<Map<String, dynamic>>(
              future: _leaderboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.translate('leaderboard_couldNotLoad'),
                      style: const TextStyle(color: Color(0xFF666666)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return Center(
                    child: Text(
                      l10n.translate('leaderboard_dataUnavailable'),
                      style: const TextStyle(color: Color(0xFF666666)),
                    ),
                  );
                }

                final data = snapshot.data!;
                final List<LeaderboardEntry> topEntries = data['topEntries'];
                final Map<String, dynamic> currentUserInfo = data['currentUserInfo'];
                final int rank = currentUserInfo['rank'] ?? 0;
                final int streak = currentUserInfo['streak'] ?? 0;

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        // Increase space below so the title sits higher
                        padding: const EdgeInsets.only(bottom: 68.0),
                        child: _GradientTwoLineTitle(
                          text: l10n.translate('leaderboard_worldwideTitle'),
                        ),
                      ),
                      LeaderboardWidget(
                        topEntries: topEntries,
                        currentUserRank: rank,
                        currentUserStreak: streak,
                        currentUserId: _currentUserId,
                        // Brand styling
                        backgroundColor: Colors.white,
                        textColor: const Color(0xFF1A1A1A),
                        titleColor: const Color(0xFF1A1A1A),
                        subtitleColor: const Color(0xFF666666),
                        currentUserHighlightColor: const Color(0xFFed3272),
                        verticalOffset: 0,
                        showHeader: false,
                      ),
                    ],
                  ),
                );
              },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GradientTwoLineTitle extends StatelessWidget {
  const _GradientTwoLineTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final String top = lines.isNotEmpty ? lines.first : text;
    final String bottom = lines.length > 1 ? lines[1] : '';

    Widget gradientText(String t, double size) => ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ).createShader(bounds),
            child: Text(
              t,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: size,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.02 * size,
                height: 1.05,
              ),
            ),
          );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          gradientText(top, 40),
          if (bottom.isNotEmpty) const SizedBox(height: 10),
          if (bottom.isNotEmpty) gradientText(bottom, 40),
        ],
      ),
    );
  }
}

