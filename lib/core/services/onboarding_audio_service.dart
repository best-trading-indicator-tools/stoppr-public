import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart' as audiosess;
import 'package:shared_preferences/shared_preferences.dart';

/// Summary: Simple singleton to play and loop the onboarding music asset
/// during the onboarding flow. Provides start/stop controls.
class OnboardingAudioService {
  OnboardingAudioService._internal();

  static final OnboardingAudioService instance = OnboardingAudioService._internal();

  AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  static const String _prefKeyEnabled = 'onboarding_music_enabled';

  // Use actual player state instead of manual tracking
  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    try {
      // Loop playback so short audio repeats until explicitly stopped.
      await _player.setReleaseMode(ReleaseMode.loop);
      // Start quietly to avoid clashing with user's other audio (0.0 - 1.0)
      await _player.setVolume(0.25);
      // Ensure iOS plays in silent mode by using playback category.
      // Safe on Android; uses media usage and music content type.
      final session = await audiosess.AudioSession.instance;
      await session.configure(const audiosess.AudioSessionConfiguration(
        avAudioSessionCategory: audiosess.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audiosess.AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: audiosess.AVAudioSessionMode.defaultMode,
        androidAudioAttributes: audiosess.AndroidAudioAttributes(
          contentType: audiosess.AndroidAudioContentType.music,
          usage: audiosess.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: audiosess.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);
      _isInitialized = true;
      // Respect persisted preference immediately on init
      final enabled = await _getSavedEnabled();
      if (!enabled) {
        // Ensure nothing is playing if user previously disabled
        try {
          await _player.stop();
        } catch (_) {}
      }
      if (kDebugMode) {
        debugPrint('OnboardingAudioService: initialized (enabled=$enabled)');
      }
    } catch (e) {
      debugPrint('OnboardingAudioService init error: $e');
    }
  }

  Future<bool> _getSavedEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyEnabled) ?? true; // default enabled
    } catch (_) {
      return true;
    }
  }

  Future<void> _setSavedEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, value);
    } catch (_) {}
  }

  Future<void> start() async {
    try {
      await startWithAsset('sounds/onboarding_528HZ.mp3');
    } catch (e) {
      debugPrint('OnboardingAudioService start error: $e');
    }
  }

  Future<void> startWithAsset(String assetPath) async {
    try {
      debugPrint('🎵 OnboardingAudioService: startWithAsset($assetPath) called');
      await _ensureInitialized();
      debugPrint('🎵 OnboardingAudioService: Initialized, stopping any existing playback...');
      
      // Just stop any existing audio, don't release (we're about to play again)
      try {
        await _player.stop();
      } catch (e) {
        debugPrint('🎵 OnboardingAudioService: Error stopping previous audio (OK if none playing): $e');
      }
      
      debugPrint('🎵 OnboardingAudioService: Starting playback of $assetPath...');
      await _player.play(AssetSource(assetPath));
      
      // Check actual player state after starting
      final playerState = _player.state;
      debugPrint('🎵 OnboardingAudioService: Player state after play: $playerState');
      
      await _setSavedEnabled(true);
      debugPrint('🎵 OnboardingAudioService: Preference saved as enabled');
    } catch (e) {
      debugPrint('🎵 OnboardingAudioService startWithAsset error: $e');
    }
  }

  Future<void> startWithAssetIfEnabled(String assetPath) async {
    if (await _getSavedEnabled()) {
      await startWithAsset(assetPath);
    } else {
      // Ensure initialized even if not playing so toggling works instantly
      await _ensureInitialized();
    }
  }

  Future<void> stop() async {
    try {
      debugPrint('🎵 OnboardingAudioService: stop() called, player state=${_player.state}');
      
      // CRITICAL FIX: Always try to stop, even if state looks wrong (hot reload issue)
      // The player state can be stale after hot reload, but audio might still be playing
      debugPrint('🎵 OnboardingAudioService: Force-stopping audio regardless of state...');
      
      try {
        await _player.stop();
        debugPrint('🎵 OnboardingAudioService: _player.stop() completed');
      } catch (e) {
        debugPrint('🎵 OnboardingAudioService: Error during stop (continuing): $e');
      }
      
      try {
        await _player.release();
        debugPrint('🎵 OnboardingAudioService: _player.release() completed - audio resources fully released');
      } catch (e) {
        debugPrint('🎵 OnboardingAudioService: Error during release (continuing): $e');
      }

      // Extra hard stop: deactivate the shared audio session so iOS kills lingering audio
      try {
        final session = await audiosess.AudioSession.instance;
        await session.setActive(false);
        debugPrint('🎵 OnboardingAudioService: Audio session deactivated');
      } catch (e) {
        debugPrint('🎵 OnboardingAudioService: Error deactivating audio session (continuing): $e');
      }
      
      // After release(), the player is disposed and cannot be reused
      // Create a fresh AudioPlayer instance for next time
      debugPrint('🎵 OnboardingAudioService: Creating new AudioPlayer instance after release...');
      _player = AudioPlayer();
      _isInitialized = false; // Reset initialization flag so next play re-configures
      debugPrint('🎵 OnboardingAudioService: New player created, ready for next playback');
      
      await _setSavedEnabled(false);
      debugPrint('🎵 OnboardingAudioService: Preference saved as disabled');
    } catch (e) {
      debugPrint('🎵 OnboardingAudioService stop error: $e');
      // Even on error, try to create a fresh player to avoid stuck state
      try {
        _player = AudioPlayer();
        _isInitialized = false;
      } catch (_) {}
    }
  }
}


