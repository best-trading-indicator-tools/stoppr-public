import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefensiveAssetImageProvider extends ImageProvider<DefensiveAssetImageProvider> {
  final String assetPath;
  final double scale;
  final Color fallbackColor;

  const DefensiveAssetImageProvider(
    this.assetPath, {
    this.scale = 1.0,
    this.fallbackColor = Colors.grey,
  });

  @override
  Future<DefensiveAssetImageProvider> obtainKey(ImageConfiguration configuration) async => this;

  @override
  ImageStreamCompleter loadBuffer(DefensiveAssetImageProvider key, DecoderBufferCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsyncDefensive(key, decode),
      scale: scale,
    );
  }

  Future<ui.Codec> _loadAsyncDefensive(DefensiveAssetImageProvider key, DecoderBufferCallback decode) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android: Use defensive loading to catch Samsung crashes
      try {
        final ByteData data = await rootBundle.load(assetPath);
        final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(data.buffer.asUint8List());
        return await decode(buffer);
      } catch (e, stackTrace) {
        debugPrint('Samsung decoder failed for $assetPath: $e');
        debugPrint('Fixing image for Samsung compatibility...');
        
        // Fix the image by re-encoding it clean
        final ByteData originalData = await rootBundle.load(assetPath);
        final Uint8List originalBytes = originalData.buffer.asUint8List();
        
        // Use completer to handle the callback-based decoder
        final Completer<ui.Image> completer = Completer<ui.Image>();
        ui.decodeImageFromList(originalBytes, (ui.Image image) {
          completer.complete(image);
        });
        final ui.Image rawImage = await completer.future;
        
        // Re-encode as clean PNG (removes Samsung-incompatible metadata/compression)
        final ByteData? cleanImageData = await rawImage.toByteData(format: ui.ImageByteFormat.png);
        if (cleanImageData == null) {
          throw Exception('Failed to encode image data');
        }
        final ui.ImmutableBuffer cleanBuffer = await ui.ImmutableBuffer.fromUint8List(cleanImageData.buffer.asUint8List());
        
        debugPrint('Fixed image for Samsung: $assetPath');
        return await decode(cleanBuffer);
      }
    } else {
      // iOS: Use normal loading (no changes)
      final ByteData data = await rootBundle.load(assetPath);
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(data.buffer.asUint8List());
      return await decode(buffer);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefensiveAssetImageProvider &&
          runtimeType == other.runtimeType &&
          assetPath == other.assetPath &&
          scale == other.scale &&
          fallbackColor == other.fallbackColor;

  @override
  int get hashCode => Object.hash(assetPath, scale, fallbackColor);
}