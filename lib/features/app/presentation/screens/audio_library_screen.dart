import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/services/remote_audio_service.dart';
import 'audio_player_screen.dart';
import 'main_scaffold.dart';

class AudioItem {
  final String id;
  final String title;
  final String audioPath;
  final String thumbnailPath;
  
  const AudioItem({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.thumbnailPath,
  });
}

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  // List of available audio items
  final List<AudioItem> _audioItems = [
    const AudioItem(
      id: 'nsdr',
      title: 'audioLibrary_nsdr_title', // localization key; translate at render
      audioPath: 'sounds/NSDR.mp3',
      thumbnailPath: 'assets/images/learn_videos/nsdr_thumbnail.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Audio Library Screen');
    
    // Set status bar icons to dark for this screen
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            MixpanelService.trackButtonTap('Back', screenName: 'Audio Library Screen');
            // Navigate back to main scaffold index 0 (Home)
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainScaffold(initialIndex: 0),
              ),
            );
          },
        ),
        title: Text(
          l10n.translate('audioLibraryScreen_title'),
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('audioLibraryScreen_subtitle'),
              style: const TextStyle(
                color: Colors.black87,
                fontFamily: 'ElzaRound',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _audioItems.length,
                itemBuilder: (context, index) {
                  final audioItem = _audioItems[index];
                  return _buildAudioCard(audioItem);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCard(AudioItem audioItem) {
    return GestureDetector(
      onTap: () async {
        MixpanelService.trackButtonTap('Audio Item: ${audioItem.title}', screenName: 'Audio Library Screen');
        
        // Show loading dialog while downloading
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        
        // Download audio file from Firebase Storage
        final audioPath = await RemoteAudioService.getAudioPath(audioItem.id);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        if (audioPath != null && mounted) {
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: AudioPlayerScreen(
                title: AppLocalizations.of(context)!.translate(audioItem.title),
                audioPath: audioPath,
                isLocalFile: true,
              ),
              settings: const RouteSettings(name: '/audio_player'),
            ),
          );
        } else if (mounted) {
          // Show error message if download failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.translate('audioLibrary_download_error'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  image: DecorationImage(
                    image: AssetImage(audioItem.thumbnailPath),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      // Handle image loading error
                      debugPrint('Error loading image: ${audioItem.thumbnailPath}');
                    },
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            // Title
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.translate(audioItem.title),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 