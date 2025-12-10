import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/learn/domain/models/learn_video_lesson.dart';

part 'learn_video_state.dart';
part 'learn_video_cubit.freezed.dart';

const String _completedLessonsPrefsKey = 'completed_learn_video_lessons';

class LearnVideoCubit extends Cubit<LearnVideoState> {
  LearnVideoCubit() : super(const LearnVideoState.initial());

  List<LearnVideoLesson> _allLessons = []; // To store the master list of lessons
  
  // Available subtitle languages
  static const List<String> _availableLanguages = ['en', 'es', 'de', 'fr', 'ru', 'zh', 'sk', 'cs'];
  
  /// Generates subtitle asset paths for a given lesson
  static Map<String, String> _generateSubtitlePaths(int lessonNumber, String lessonKey) {
    final Map<String, String> paths = {};
    for (final lang in _availableLanguages) {
      paths[lang] = 'assets/subtitles/extracted/lesson_${lessonNumber}_${lessonKey}_$lang.srt';
    }
    return paths;
  }

  // Placeholder for actual lesson data - this should be populated
  // from a configuration or a more robust source eventually.
  final List<LearnVideoLesson> _initialLessonsData = [
    LearnVideoLesson(
      id: "lesson_1",
      title: "learnVideoLesson_1_title", // Now using localization key
      duration: "1 min",
      videoAssetPath: "https://stream.mux.com/J5gOhGoWriYLFjSMIfWuzJmog6wIKYAIeptbtiH7FY00.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/1 - Welcome to Stoppr.png",
      subtitleAssetPaths: _generateSubtitlePaths(1, "welcome_to_stoppr"),
    ),
    LearnVideoLesson(
      id: "lesson_2",
      title: "learnVideoLesson_2_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/di4zKUD02bXq8c2vbqkhBWzGOw62zuGT00MT2EPmucQ1w.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/2 - Where is sugar hiding.png",
      subtitleAssetPaths: _generateSubtitlePaths(2, "where_sugar_hides"),
    ),
    LearnVideoLesson(
      id: "lesson_3",
      title: "learnVideoLesson_3_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/vAfRBH41Abl400diAuGPcMza01rGsRgXgzcOSpp01oPzlU.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/3 - Understanding cravings.png",
      subtitleAssetPaths: _generateSubtitlePaths(3, "understanding_cravings"),
    ),
    LearnVideoLesson(
      id: "lesson_4",
      title: "learnVideoLesson_4_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/001t6V00GkCnzNJ6OyeMedSFrwBjw21jUhcln01fbPp6Ns.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/4 - Building healthy habits.png",
      subtitleAssetPaths: _generateSubtitlePaths(4, "building_healthy_habits"),
    ),
    LearnVideoLesson(
      id: "lesson_5",
      title: "learnVideoLesson_5_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/uswKoucF8VvQoyTWHCutvWm9U8w01jYGFMnk0002GTmbN8.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/5.png",
      subtitleAssetPaths: _generateSubtitlePaths(5, "dont_use_sugar_for_work"),
    ),
    LearnVideoLesson(
      id: "lesson_6",
      title: "learnVideoLesson_6_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/1EnbMIJ42u5Zn02d5fPLssk7fBbXL5m2um7Tr4lEFm3s.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/6 - Sugar is not a feelings fixer.png",
      subtitleAssetPaths: _generateSubtitlePaths(6, "dont_use_sugar_for_feelings"),
    ),
    LearnVideoLesson(
      id: "lesson_7",
      title: "learnVideoLesson_7_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/BHE02XdSOL022zjIQ5HKaMRUjie1Y01uPAJjZe3qPTqs2g.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/7 - Sport to fix your sugar life.png",
      subtitleAssetPaths: _generateSubtitlePaths(7, "sport_to_kill_sugar_life"),
    ),
    LearnVideoLesson(
      id: "lesson_8",
      title: "learnVideoLesson_8_title", // Now using localization key
      duration: "2 min",
      videoAssetPath: "https://stream.mux.com/evWDc02RSiErotEYsNnl001vl75oOfOP2xge501UUBHM94.m3u8",
      thumbnailAssetPath: "assets/images/learn/thumbnails/8 - Kill sugar peer pressure.png",
      subtitleAssetPaths: _generateSubtitlePaths(8, "kill_sugar_peer_pressure"),
    ),
  ];

  Future<void> loadLessons() async {
    emit(const LearnVideoState.loading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedLessonIds = prefs.getStringList(_completedLessonsPrefsKey) ?? [];

      _allLessons = _initialLessonsData.map((lesson) {
        return lesson.copyWith(isCompleted: completedLessonIds.contains(lesson.id));
      }).toList();

      _updateLockStatus();
      
      bool showComingSoonMessage = false;
      if (_allLessons.length >= 8) {
        final lesson8 = _allLessons.firstWhere(
            (lesson) => lesson.id == 'lesson_8', 
            orElse: () => LearnVideoLesson(id: '', title: '', duration: '', videoAssetPath: '', isCompleted: false)
        );
        showComingSoonMessage = lesson8.id.isNotEmpty && lesson8.isCompleted;
      }
      emit(LearnVideoState.loaded(lessons: List.from(_allLessons), showComingSoonMessage: showComingSoonMessage));
    } catch (e) {
      emit(LearnVideoState.error("Failed to load lessons: ${e.toString()}"));
    }
  }

  void _updateLockStatus() {
    bool previousLessonCompleted = true; // First lesson is always unlocked
    List<LearnVideoLesson> updatedLessons = [];

    for (int i = 0; i < _allLessons.length; i++) {
      final lesson = _allLessons[i];
      bool currentLessonLocked;
      if (i == 0) {
        currentLessonLocked = false; // First lesson is never locked
      } else {
        currentLessonLocked = !previousLessonCompleted;
      }
      updatedLessons.add(lesson.copyWith(isLocked: currentLessonLocked));
      previousLessonCompleted = lesson.isCompleted;
    }
    _allLessons = updatedLessons;
  }

  Future<void> markLessonCompleted(String lessonId) async {
    // Optimistically update local data first
    _allLessons = _allLessons.map((lesson) {
      if (lesson.id == lessonId) {
        return lesson.copyWith(isCompleted: true);
      }
      return lesson;
    }).toList();
    _updateLockStatus(); // Reflects optimistic completion

    // Calculate showComingSoon based on optimistically updated _allLessons
    bool showComingSoonOpt = false;
    if (_allLessons.length >= 8) {
        final lesson8 = _allLessons.firstWhere(
            (lesson) => lesson.id == 'lesson_8', 
            orElse: () => LearnVideoLesson(id: '', title: '', duration: '', videoAssetPath: '', isCompleted: false)
        );
        showComingSoonOpt = lesson8.id.isNotEmpty && lesson8.isCompleted;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> completedLessonIds = prefs.getStringList(_completedLessonsPrefsKey) ?? [];
      if (!completedLessonIds.contains(lessonId)) {
        completedLessonIds.add(lessonId);
        await prefs.setStringList(_completedLessonsPrefsKey, completedLessonIds);
      }
      // If successful, emit the new state without error
      emit(LearnVideoState.loaded(
        lessons: List.from(_allLessons),
        showComingSoonMessage: showComingSoonOpt
      ));
    } catch (e) {
      print("Error marking lesson completed: ${e.toString()}");
      // Emit optimistically updated lessons but with an error message
      emit(LearnVideoState.loaded(
        lessons: List.from(_allLessons), 
        showComingSoonMessage: showComingSoonOpt,
        error: "Failed to save completion status. Please try again.",
      ));
    }
  }

  // Optional: for resetting progress during development/testing
  Future<void> resetProgress() async {
    emit(const LearnVideoState.loading());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_completedLessonsPrefsKey);
      _allLessons = _initialLessonsData.map((lesson) => lesson.copyWith(isCompleted: false)).toList();
      _updateLockStatus();
      
      // After reset, lesson 8 (if exists) won't be completed, so showComingSoonMessage is false.
      bool showComingSoonMessage = false;
      if (_allLessons.length >= 8) {
        final lesson8 = _allLessons.firstWhere(
            (lesson) => lesson.id == 'lesson_8',
            orElse: () => LearnVideoLesson(id: '', title: '', duration: '', videoAssetPath: '', isCompleted: false)
        );
        // This check is technically redundant after a full reset for lesson 8, 
        // as it would be marked not completed. But kept for consistency.
        showComingSoonMessage = lesson8.id.isNotEmpty && lesson8.isCompleted; 
      }
      emit(LearnVideoState.loaded(lessons: List.from(_allLessons), showComingSoonMessage: showComingSoonMessage));
    } catch (e) {
      emit(LearnVideoState.error("Failed to reset progress: ${e.toString()}"));
    }
  }
} 