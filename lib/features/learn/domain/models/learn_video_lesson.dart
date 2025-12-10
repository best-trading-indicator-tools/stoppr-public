import 'package:freezed_annotation/freezed_annotation.dart';

part 'learn_video_lesson.freezed.dart';
part 'learn_video_lesson.g.dart';

@freezed
class LearnVideoLesson with _$LearnVideoLesson {
  const LearnVideoLesson._();
  
  const factory LearnVideoLesson({
    required String id, // Unique identifier (e.g., "lesson_1")
    required String title, // Direct English title
    required String duration, // Formatted duration string (e.g., "1 min", "2 min")
    required String videoAssetPath, // Path to the video file in assets (e.g., "assets/videos/learn/lesson_1.mp4")
    String? subtitleAssetPath, // Optional path to local subtitle file (e.g., "assets/subtitles/lesson_1.srt") - DEPRECATED
    @Default({}) Map<String, String> subtitleAssetPaths, // Map of language codes to subtitle file paths (e.g., {"en": "assets/subtitles/extracted/lesson_1_en.srt", "fr": "..."})
    String? thumbnailAssetPath, // Path to the thumbnail image in assets (e.g., "assets/images/learn_videos/lesson_1_thumbnail.png")
    String? muxPlaybackId, // Optional Mux playback ID for fetching thumbnails
    @Default(false) bool isCompleted,
    @Default(false) bool isLocked, // For UI state, derived from completion status of previous lessons
  }) = _LearnVideoLesson;

  factory LearnVideoLesson.fromJson(Map<String, dynamic> json) => _$LearnVideoLessonFromJson(json);
  
  /// Gets the subtitle path for the given language code
  /// Falls back to English if the requested language is not available
  /// Falls back to the deprecated subtitleAssetPath if no multilingual subtitles are available
  String? getSubtitlePath(String languageCode) {
    // First, try to get from the new multilingual subtitles
    if (subtitleAssetPaths.isNotEmpty) {
      // Return the requested language if available
      if (subtitleAssetPaths.containsKey(languageCode)) {
        return subtitleAssetPaths[languageCode];
      }
      // Fall back to English
      if (subtitleAssetPaths.containsKey('en')) {
        return subtitleAssetPaths['en'];
      }
      // Return any available subtitle as last resort
      return subtitleAssetPaths.values.first;
    }
    
    // Fall back to the deprecated single subtitle path
    return subtitleAssetPath;
  }
  
  /// Checks if subtitles are available for the given language
  bool hasSubtitlesForLanguage(String languageCode) {
    return subtitleAssetPaths.containsKey(languageCode) || subtitleAssetPath != null;
  }
  
  /// Gets all available subtitle languages
  List<String> get availableSubtitleLanguages {
    final languages = subtitleAssetPaths.keys.toList();
    if (subtitleAssetPath != null && languages.isEmpty) {
      languages.add('en'); // Assume deprecated subtitle is English
    }
    return languages;
  }
} 