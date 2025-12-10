import 'package:flutter/material.dart';
import 'package:stoppr/core/services/onboarding_audio_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

/// Summary: Reusable sound on/off toggle used across onboarding screens.
/// Shows a pulsing animation when music is playing. Positioned by parent.
class OnboardingSoundToggle extends StatefulWidget {
  final String? eventName; // Optional Mixpanel event name
  final double diameter; // Circle diameter for sizing
  const OnboardingSoundToggle({super.key, this.eventName, this.diameter = 44});

  @override
  State<OnboardingSoundToggle> createState() => _OnboardingSoundToggleState();
}

class _OnboardingSoundToggleState extends State<OnboardingSoundToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // If not playing, keep animation stopped at 1.0 scale
    if (!OnboardingAudioService.instance.isPlaying) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    debugPrint('🔊 OnboardingSoundToggle: _toggle() called');
    final svc = OnboardingAudioService.instance;
    final wasPlayingBefore = svc.isPlaying;
    debugPrint('🔊 OnboardingSoundToggle: Current isPlaying state: $wasPlayingBefore');
    
    // Simple toggle: if playing, stop. If stopped, start.
    if (wasPlayingBefore) {
      debugPrint('🔊 OnboardingSoundToggle: Stopping audio...');
      await svc.stop();
      debugPrint('🔊 OnboardingSoundToggle: Audio stopped, isPlaying now: ${svc.isPlaying}');
      if (mounted) {
        _controller.animateTo(0.0, duration: const Duration(milliseconds: 200));
        _controller.stop();
        debugPrint('🔊 OnboardingSoundToggle: Animation stopped');
      }
    } else {
      debugPrint('🔊 OnboardingSoundToggle: Starting audio...');
      await svc.start();
      debugPrint('🔊 OnboardingSoundToggle: Audio started, isPlaying now: ${svc.isPlaying}');
      if (mounted) {
        _controller.repeat(reverse: true);
        debugPrint('🔊 OnboardingSoundToggle: Animation started');
      }
    }
    
    if (widget.eventName != null && widget.eventName!.isNotEmpty) {
      debugPrint('🔊 OnboardingSoundToggle: Tracking event: ${widget.eventName}');
      MixpanelService.trackEvent(widget.eventName!);
    }
    
    // Force rebuild to update UI
    if (mounted) {
      debugPrint('🔊 OnboardingSoundToggle: Calling setState to rebuild');
      setState(() {});
      
      // Extra safety: Force another rebuild after a tiny delay to catch any async state changes
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {});
          debugPrint('🔊 OnboardingSoundToggle: Safety rebuild completed');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.diameter * 0.55;
    final isPlaying = OnboardingAudioService.instance.isPlaying;
    debugPrint('🔊 OnboardingSoundToggle: Building with isPlaying=$isPlaying');
    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: ScaleTransition(
          scale: _scale,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: widget.diameter,
              height: widget.diameter,
            ),
            icon: Icon(
              isPlaying
                  ? Icons.volume_up
                  : Icons.volume_off,
              color: Colors.white,
              size: iconSize,
            ),
            tooltip: isPlaying
                ? 'Stop Music'
                : 'Play Music',
            onPressed: _toggle,
          ),
        ),
      ),
    );
  }
}


