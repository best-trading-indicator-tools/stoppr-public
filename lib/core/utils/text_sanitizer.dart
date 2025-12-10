import 'dart:convert';
import 'package:flutter/material.dart';

/// Utility class for sanitizing text to prevent UTF-16 encoding crashes.
/// 
/// This class provides methods to clean strings that may contain malformed
/// UTF-16 sequences, unpaired surrogates, or problematic control characters
/// that could cause crashes in Flutter's text rendering pipeline.
class TextSanitizer {
  /// Checks if a string contains valid UTF-16 encoding.
  /// 
  /// Returns true if the string is safe to use in Flutter widgets,
  /// false if it contains malformed UTF-16 sequences.
  static bool isValidUtf16(String input) {
    if (input.isEmpty) return true;
    
    try {
      // Try encoding/decoding to validate UTF-16
      final bytes = utf8.encode(input);
      final decoded = utf8.decode(bytes, allowMalformed: false);
      
      // Check for unpaired surrogates
      final codeUnits = input.codeUnits;
      for (int i = 0; i < codeUnits.length; i++) {
        final codeUnit = codeUnits[i];
        
        // Check for high surrogate
        if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
          // High surrogate found, check if there's a matching low surrogate
          if (i + 1 >= codeUnits.length) return false;
          final nextCodeUnit = codeUnits[i + 1];
          if (nextCodeUnit < 0xDC00 || nextCodeUnit > 0xDFFF) return false;
          i++; // Skip the next code unit as it's part of the pair
        } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
          // Unpaired low surrogate
          return false;
        }
      }
      
      return decoded == input;
    } catch (e) {
      debugPrint('UTF-16 validation failed: $e');
      return false;
    }
  }
  /// Sanitizes strings to prevent UTF-16 encoding crashes in TextSpan/Text widgets.
  /// 
  /// This method:
  /// - Validates strings by encoding/decoding through UTF-8
  /// - Removes null characters and control characters
  /// - Removes unpaired UTF-16 surrogate pairs
  /// - Validates UTF-16 code units
  /// - Provides a safe fallback for extreme cases
  /// 
  /// Use this for any external data (API responses, user input, etc.) before
  /// displaying in Text or TextSpan widgets.
  static String sanitizeForDisplay(String input) {
    if (input.isEmpty) return input;
    
    // Fast path: if the string is already valid UTF-16, return it unchanged
    if (isValidUtf16(input)) {
      return input;
    }
    
    try {
      debugPrint('TextSanitizer: Processing potentially malformed UTF-16 string');
      
      // First, validate the string by encoding/decoding through UTF-8
      final bytes = utf8.encode(input);
      final decoded = utf8.decode(bytes, allowMalformed: true);
      
      // Validate UTF-16 code units and remove malformed sequences
      final codeUnits = decoded.codeUnits;
      final List<int> validCodeUnits = [];
      int invalidCharCount = 0;
      
      for (int i = 0; i < codeUnits.length; i++) {
        final codeUnit = codeUnits[i];
        
        // Check for high surrogate
        if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
          // High surrogate found, check if there's a matching low surrogate
          if (i + 1 < codeUnits.length) {
            final nextCodeUnit = codeUnits[i + 1];
            if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
              // Valid surrogate pair
              validCodeUnits.add(codeUnit);
              validCodeUnits.add(nextCodeUnit);
              i++; // Skip the next code unit as it's part of the pair
              continue;
            }
          }
          // Invalid high surrogate, skip it
          invalidCharCount++;
          continue;
        }
        
        // Check for low surrogate without preceding high surrogate
        if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
          // Invalid low surrogate, skip it
          invalidCharCount++;
          continue;
        }
        
        // Check for null characters and control characters
        if (codeUnit == 0x00 || 
            (codeUnit >= 0x00 && codeUnit <= 0x08) ||
            (codeUnit >= 0x0B && codeUnit <= 0x0C) ||
            (codeUnit >= 0x0E && codeUnit <= 0x1F) ||
            codeUnit == 0x7F) {
          // Skip control characters except \t (0x09), \n (0x0A), \r (0x0D)
          invalidCharCount++;
          continue;
        }
        
        // Valid code unit
        validCodeUnits.add(codeUnit);
      }
      
      if (invalidCharCount > 0) {
        debugPrint('TextSanitizer: Removed $invalidCharCount invalid characters');
      }
      
      final sanitizedString = String.fromCharCodes(validCodeUnits);
      
      // Final validation to ensure the result is safe
      if (!isValidUtf16(sanitizedString)) {
        debugPrint('TextSanitizer: Final validation failed, using fallback');
        return _getSafeFallback(input);
      }
      
      return sanitizedString;
    } catch (e) {
      debugPrint('Error sanitizing string for display: $e');
      return _getSafeFallback(input);
    }
  }
  
  /// Provides a safe fallback string when sanitization fails completely
  static String _getSafeFallback(String input) {
    try {
      // Try to preserve ASCII characters only
      return input.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '?');
    } catch (e2) {
      debugPrint('Fallback sanitization also failed: $e2');
      return 'Invalid text content';
    }
  }

  /// UTF-16 safe substring that avoids cutting surrogate pairs.
  /// 
  /// This method prevents crashes when substring operations would cut
  /// in the middle of a UTF-16 surrogate pair (emojis, certain international chars).
  /// 
  /// Use this instead of .substring() when progressively revealing text
  /// (typewriter effects) or truncating user/external content.
  static String safeSubstring(String input, int start, [int? end]) {
    if (input.isEmpty) return input;
    
    final length = input.length;
    final actualEnd = end ?? length;
    
    // Ensure bounds are valid
    if (start < 0 || start > length) return input;
    if (actualEnd < start || actualEnd > length) return input;
    
    // Adjust start if it would cut a surrogate pair
    int safeStart = start;
    if (safeStart > 0 && safeStart < length) {
      final codeUnit = input.codeUnitAt(safeStart);
      // If we're starting at a low surrogate, move back one
      if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
        safeStart = (safeStart - 1).clamp(0, length);
      }
    }
    
    // Adjust end if it would cut a surrogate pair
    int safeEnd = actualEnd;
    if (safeEnd > 0 && safeEnd < length) {
      final codeUnit = input.codeUnitAt(safeEnd - 1);
      // If the last character is a high surrogate, move end back one
      if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
        safeEnd = (safeEnd - 1).clamp(safeStart, length);
      }
    }
    
    try {
      return input.substring(safeStart, safeEnd);
    } catch (e) {
      debugPrint('TextSanitizer: Safe substring failed: $e');
      return input;
    }
  }

  /// Creates a safe TextSpan with automatic sanitization.
  /// 
  /// This method ensures that all text content in the TextSpan is sanitized
  /// before being passed to the dart:ui rendering pipeline.
  static TextSpan createSafeTextSpan({
    required String text,
    TextStyle? style,
    List<TextSpan>? children,
  }) {
    try {
      final safeText = sanitizeForDisplay(text);
      final safeChildren = children?.map((child) => 
        createSafeTextSpan(
          text: child.text ?? '',
          style: child.style,
          children: child.children?.cast<TextSpan>(),
        )
      ).toList();
      
      return TextSpan(
        text: safeText,
        style: style,
        children: safeChildren,
      );
    } catch (e) {
      debugPrint('Error creating safe TextSpan: $e');
      return TextSpan(
        text: sanitizeForDisplay(text),
        style: style,
      );
    }
  }

  /// Creates a safe RichText widget with automatic sanitization.
  /// 
  /// This method wraps the TextSpan creation in error handling to prevent
  /// crashes from malformed UTF-16 strings.
  static Widget createSafeRichText({
    required TextSpan textSpan,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    TextScaler textScaler = const TextScaler.linear(1.0),
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
  }) {
    try {
      return RichText(
        text: textSpan,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        locale: locale,
        strutStyle: strutStyle,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      );
    } catch (e) {
      debugPrint('Error creating RichText: $e');
      // Fallback to simple Text widget
      return Text(
        sanitizeForDisplay(textSpan.text ?? ''),
        textAlign: textAlign,
        textDirection: textDirection,
        overflow: overflow,
        maxLines: maxLines,
      );
    }
  }
}

/// A safe wrapper for Flutter's Text widget that automatically sanitizes text content.
/// 
/// This widget ensures that any text passed to it is properly sanitized to prevent
/// UTF-16 encoding crashes. Use this widget anywhere you display external data,
/// user input, or any text that might contain malformed UTF-16 sequences.
class SafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final sanitizedText = TextSanitizer.sanitizeForDisplay(text);
      
      return Text(
        sanitizedText,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    } catch (e) {
      debugPrint('SafeText: Error rendering text widget: $e');
      // Ultra-safe fallback
      return Text(
        'Text rendering error',
        style: style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red),
      );
    }
  }
}

/// A safe wrapper for Flutter's RichText widget that automatically sanitizes text content.
/// 
/// This widget ensures that any TextSpan content is properly sanitized to prevent
/// UTF-16 encoding crashes.
class SafeRichText extends StatelessWidget {
  final TextSpan text;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const SafeRichText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.textScaler = const TextScaler.linear(1.0),
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final sanitizedTextSpan = TextSanitizer.createSafeTextSpan(
        text: text.text ?? '',
        style: text.style,
        children: text.children?.cast<TextSpan>(),
      );
      
      return RichText(
        text: sanitizedTextSpan,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        locale: locale,
        strutStyle: strutStyle,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    } catch (e) {
      debugPrint('SafeRichText: Error rendering rich text widget: $e');
      // Ultra-safe fallback
      return Text(
        'Rich text rendering error',
        style: text.style?.copyWith(color: Colors.red) ?? const TextStyle(color: Colors.red),
      );
    }
  }
}
