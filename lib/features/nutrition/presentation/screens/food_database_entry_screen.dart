import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';
import 'package:stoppr/features/nutrition/data/models/food_log.dart';
import 'package:stoppr/features/nutrition/data/models/nutrition_goals.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as record;
import 'package:dart_openai/dart_openai.dart';
import 'package:stoppr/core/config/env_config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:stoppr/features/nutrition/data/models/nutrition_data.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'nutrient_edit_screen.dart';

/// Summary: Manual food entry screen that looks EXACTLY like the 
/// "Selected food" screen with tappable nutrient sections
class FoodDatabaseEntryScreen extends StatefulWidget {
  const FoodDatabaseEntryScreen({super.key, required this.targetDate});

  final DateTime targetDate;

  @override
  State<FoodDatabaseEntryScreen> createState() => _FoodDatabaseEntryScreenState();
}

class _FoodDatabaseEntryScreenState extends State<FoodDatabaseEntryScreen> {
  final _repo = NutritionRepository();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameCtrl = TextEditingController(text: '');
  final TextEditingController _servingsCtrl = TextEditingController(text: '1');
  final TextEditingController _caloriesCtrl = TextEditingController(text: '0');
  final FocusNode _caloriesFocus = FocusNode();
  String get _foodName => _nameCtrl.text.trim();
  double _servings = 1;
  double _calories = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fat = 0;
  double _fiber = 0;
  double _sugar = 0;
  double _sodium = 0;

  bool _isSaving = false;
  NutritionGoals? _goals;
  StreamSubscription<NutritionGoals?>? _goalsSub;

  double get _effectiveCalories => (_calories * _servings).clamp(0, double.infinity);

  // Describe & analyze controls
  final TextEditingController _describeCtrl = TextEditingController();
  bool _isAnalyzing = false;
  final record.AudioRecorder _recorder = record.AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Food Database Entry Screen');
    _goalsSub = _repo.getNutritionGoals().listen((g) {
      if (mounted) setState(() => _goals = g);
    });
    // Show effective calories by default when not editing
    _caloriesCtrl.text = _effectiveCalories.toStringAsFixed(0);
    // Rebuild to show pencil icon when focus changes
    _caloriesFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _servingsCtrl.dispose();
    _caloriesCtrl.dispose();
    _describeCtrl.dispose();
    _caloriesFocus.dispose();
    _goalsSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  DateTime _composeLogDate() {
    final now = DateTime.now();
    final d = widget.targetDate;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    // Always validate calories first
    _syncNumbersFromControllers();
    if (_effectiveCalories <= 0) {
      await _showZeroCalorieDialog();
      return;
    }

    // Allow empty name; dashboard will show localized "Unnamed food" fallback

    setState(() => _isSaving = true);

    try {
      final data = NutritionData(
        foodName: _foodName,
        calories: _effectiveCalories,
        protein: _protein,
        carbs: _carbs,
        fat: _fat,
        sugar: _sugar,
        fiber: _fiber,
        sodium: _sodium,
        servingInfo: ServingInfo(
          amount: _servings,
          unit: 'serving',
          weight: null,
          weightUnit: null,
        ),
      );

      final foodLog = FoodLog(
        userId: '',
        foodName: _foodName,
        mealType: MealType.lunch,
        nutritionData: data,
        loggedAt: _composeLogDate(),
        imageUrl: null,
      );

      await _repo.addFoodLog(foodLog);

      MixpanelService.trackButtonTap(
        'Food Database Entry Screen: Log',
        additionalProps: {
          'calories': _effectiveCalories,
          'servings': _servings,
        },
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save manual food failed: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showZeroCalorieDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.error_outline, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.translate('calorieTracker_zeroCalorie_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.translate('calorieTracker_zeroCalorie_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                // Action
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.translate('common_gotIt'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _syncNumbersFromControllers() {
    _servings = double.tryParse(_servingsCtrl.text.replaceAll(',', '.')) ?? 1;
    // Read base calories while editing and keep effective displayed when not
    final raw = double.tryParse(_caloriesCtrl.text.replaceAll(',', '.'));
    if (_caloriesFocus.hasFocus && raw != null) {
      _calories = raw; // treat input as per-serving/base value
    }
  }

  void _recalcCaloriesFromMacros() {
    final computed = (4 * _protein) + (4 * _carbs) + (9 * _fat);
    _calories = computed; // per serving
    // Update visible text according to edit state
    _caloriesCtrl.text = (_caloriesFocus.hasFocus
            ? _calories
            : _effectiveCalories)
        .toStringAsFixed(0);
  }

  Future<void> _analyzeDescription() async {
    final text = _describeCtrl.text.trim();
    if (text.isEmpty || _isAnalyzing) return;
    setState(() => _isAnalyzing = true);
    try {
      OpenAI.apiKey = EnvConfig.openaiApiKey ?? '';
      final prompt = 'You are a nutrition estimator. Given a plain English meal description, return compact JSON with fields: is_food (boolean), food_name (string), calories (kcal), protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg. Be conservative and realistic. If it is not a food/drink description, set is_food=false and put an empty object for nutrients. Description: "$text"';
      final chat = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text('Return only JSON, no prose.')],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(TextSanitizer.sanitizeForDisplay(prompt))],
          ),
        ],
      );
      final raw = chat.choices.first.message.content?.firstOrNull?.text ?? '{}';
      final Map<String, dynamic> data = _safeParseJson(raw);
      final isFood = (data['is_food'] ?? true) == true;
      if (!isFood) {
        await _showNotFoodDialog();
      } else {
        setState(() {
          final suggestedName = TextSanitizer.sanitizeForDisplay((data['food_name'] as String?)?.trim() ?? '');
          if (suggestedName != null && suggestedName.isNotEmpty) {
            _nameCtrl.text = suggestedName;
          } else if (_nameCtrl.text.trim().isEmpty || 
                     _nameCtrl.text.trim() == AppLocalizations.of(context)!.translate('calorieTracker_foodName')) {
            // If no name suggested and field is empty, use description as name
            _nameCtrl.text = TextSanitizer.sanitizeForDisplay(_describeCtrl.text.trim());
          }
          _calories = (data['calories'] ?? data['cal'] ?? 0).toDouble();
          _protein = (data['protein_g'] ?? 0).toDouble();
          _carbs = (data['carbs_g'] ?? 0).toDouble();
          _fat = (data['fat_g'] ?? 0).toDouble();
          _fiber = (data['fiber_g'] ?? 0).toDouble();
          _sugar = (data['sugar_g'] ?? 0).toDouble();
          _sodium = (data['sodium_mg'] ?? 0).toDouble();
          _caloriesCtrl.text = (_caloriesFocus.hasFocus ? _calories : _effectiveCalories).toStringAsFixed(0);
        });
      }
    } catch (e) {
      debugPrint('AI analyze failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Map<String, dynamic> _safeParseJson(String raw) {
    try {
      final cleaned = raw.trim().replaceAll('```json', '').replaceAll('```', '');
      return cleaned.isNotEmpty ? (jsonDecode(cleaned) as Map<String, dynamic>) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _recordAndAnalyze() async {
    debugPrint('🎤 Mic button tapped!');
    if (_isAnalyzing) {
      debugPrint('Already analyzing, returning');
      return;
    }
    
    // First, try using record's internal permission flow (matches chatbot)
    bool canRecord = await _recorder.hasPermission();
    debugPrint('Record.hasPermission -> $canRecord');
    if (!canRecord) {
      // Fall back to explicit request to trigger native prompt
      final status = await Permission.microphone.request();
      debugPrint('Permission.request -> $status');
      if (!status.isGranted) {
        debugPrint('❌ Microphone permission not granted');
        if (status.isPermanentlyDenied) {
          await _showMicPermissionDialog();
        }
        return;
      }
      // After explicit grant, re-check recorder permission
      canRecord = await _recorder.hasPermission();
      debugPrint('Record.hasPermission (post-request) -> $canRecord');
    }
    if (!canRecord) {
      debugPrint('❌ Recorder still has no permission');
      return;
    }

    debugPrint('✅ Microphone permission granted');

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/food_desc.m4a';
      
      debugPrint('🎙️ Starting audio recording...');
      // Show localized Recording... while capturing
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _describeCtrl.text = l10n.translate('calorieTracker_recording');
        _isRecording = true;
      });

      await _recorder.start(
        const record.RecordConfig(encoder: record.AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100),
        path: path,
      );
      
      // Tap mic again to stop; but to avoid very long recordings, cap at 6s
      await Future.delayed(const Duration(seconds: 6));
      if (!_isRecording) return; // already stopped by user
      debugPrint('⏱️ Auto-stopping after cap');
      final savedPath = await _recorder.stop();
      _isRecording = false;
      
      if (savedPath == null) {
        debugPrint('❌ No audio file saved');
        return;
      }
      
      debugPrint('💾 Audio saved to: $savedPath');

      // Transcribe with Groq STT and auto-analyze
      setState(() => _isAnalyzing = true);
      final transcription = await _groqTranscribe(File(savedPath));
      if (transcription.isNotEmpty) {
        final clean = TextSanitizer.sanitizeForDisplay(transcription);
        debugPrint('📝 Transcription: $clean');
        setState(() => _describeCtrl.text = clean);
        // Allow analyze to proceed by clearing the busy flag before triggering it
        if (mounted) setState(() => _isAnalyzing = false);
        await _analyzeDescription();
      } else {
        debugPrint('❌ Empty transcription');
      }
    } catch (e) {
      debugPrint('❌ Record/analyze error: $e');
      // keep logs only
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _showMicPermissionDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mic_none, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.translate('permissions_microphone_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.translate('permissions_microphone_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFed3272), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            l10n.translate('common_gotIt'),
                            style: const TextStyle(color: Color(0xFFed3272), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await openAppSettings();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.transparent,
                          ).merge(ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(Colors.transparent),
                          )),
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Text(
                                l10n.translate('permissions_openSettings'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _groqTranscribe(File file) async {
    try {
      final groqKey = EnvConfig.groqApiKey;
      if (groqKey == null || groqKey.isEmpty) return '';
      Future<String> send(String model) async {
        final url = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
        final req = http.MultipartRequest('POST', url);
        req.headers['Authorization'] = 'Bearer $groqKey';
        req.fields['model'] = model; // e.g., distil-whisper-large-v3
        req.files.add(await http.MultipartFile.fromPath('file', file.path));
        final res = await req.send();
        final body = await res.stream.bytesToString();
        if (res.statusCode == 200) {
          final Map<String, dynamic> j = jsonDecode(body);
          return (j['text'] as String?)?.trim() ?? '';
        }
        debugPrint('Groq STT error ${res.statusCode}: $body');
        return '';
      }
      // Per Groq docs, use turbo for lowest latency, fallback to v3 if needed
      var text = await send('whisper-large-v3-turbo');
      if (text.isEmpty) {
        text = await send('whisper-large-v3');
      }
      return text;
    } catch (e) {
      debugPrint('Groq STT exception: $e');
      return '';
    }
  }

  Future<void> _showNotFoodDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.error_outline, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.translate('calorieTracker_notFood_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.translate('calorieTracker_notFood_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.translate('common_gotIt'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Text(l10n.translate('calorieTracker_nutrition')),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              
              // Food name (section card)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      maxLines: null, // allow full analyzed name to wrap
                      minLines: 1,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n.translate('calorieTracker_foodName'),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                    const SizedBox(width: 12),
                  SizedBox(
                      width: 96,
                    child: TextField(
                      controller: _servingsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFed3272), width: 2),
                        ),
                          suffixIcon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black45),
                        ),
                        onChanged: (_) => setState(() {
                          _syncNumbersFromControllers();
                          _caloriesCtrl.text = (_caloriesFocus.hasFocus
                                  ? _calories
                                  : _effectiveCalories)
                              .toStringAsFixed(0);
                        }),
                    ),
                  ),
                ],
                ),
              ),
              const SizedBox(height: 16),
              // Global hint that everything is editable
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.translate('calorieTracker_editable_hint_top'),
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Describe what you ate (AI-powered)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('calorieTracker_ai_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _describeCtrl,
                      maxLines: 5,
                      minLines: 3,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: l10n.translate('calorieTracker_describeHint'),
                        hintStyle: const TextStyle(color: Color(0xFF666666)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFed3272), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onChanged: (_) {
                        // Don't update name field until analyze is pressed
                      },
                      onSubmitted: (_) => _analyzeDescription(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.translate('calorieTracker_ai_helper_line'),
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _analyzeDescription,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ).merge(ButtonStyle(
                                // Keep gradient visible even when disabled/busy
                                overlayColor: MaterialStateProperty.all(Colors.transparent),
                                foregroundColor: MaterialStateProperty.all(Colors.white),
                                backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                shadowColor: MaterialStateProperty.all(Colors.transparent),
                              )),
                              child: Ink(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                  ),
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Text(
                                    _isAnalyzing
                                        ? l10n.translate('calorieTracker_analyzingDesc')
                                        : l10n.translate('calorieTracker_analyze'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _MicAnalyzeButton(onTap: _recordAndAnalyze, isBusy: _isRecording),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Manual entry title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.translate('calorieTracker_manual_title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Calories section (card)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                        ),
                      ],
                    ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caloriesCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        focusNode: _caloriesFocus,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFed3272), width: 2),
                          ),
                          suffixIcon: _caloriesFocus.hasFocus
                              ? const Icon(Icons.edit_outlined, size: 18, color: Colors.black45)
                              : null,
                        ),
                        cursorColor: Color(0xFFed3272),
                        onChanged: (_) => setState(() {
                          _syncNumbersFromControllers();
                        }),
                        onEditingComplete: () {
                          // When leaving the field, switch to showing effective value
                          setState(() {
                            _caloriesCtrl.text = _effectiveCalories.toStringAsFixed(0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.translate('calorieTracker_calories'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildEmojiRingWithProgress('🔥', _calorieProgress()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              const SizedBox(height: 40),

              // Macros cards - Page 1
              SizedBox(
                height: 150,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    // Page 1: Protein, Carbs, Fats
                    Row(
                      children: [
                        Expanded(
                          child: _buildMacroCard(
                            emoji: '🥩',
                            label: l10n.translate('calorieTracker_protein'),
                            value: _protein,
                            unit: l10n.translate('unit_g'),
                            progress: _macroProgress(
                              _protein,
                              (_goals?.protein ?? 150).toDouble(),
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NutrientEditScreen(
                                    nutrientLabelKey: 'calorieTracker_protein',
                                    unitKey: 'unit_g',
                                    initialValue: _protein,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _protein = result;
                                  _recalcCaloriesFromMacros();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMacroCard(
                            emoji: '🌾',
                            label: l10n.translate('calorieTracker_carbs'),
                            value: _carbs,
                            unit: l10n.translate('unit_g'),
                            progress: _macroProgress(
                              _carbs,
                              (_goals?.carbs ?? 161).toDouble(),
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NutrientEditScreen(
                                    nutrientLabelKey: 'calorieTracker_carbs',
                                    unitKey: 'unit_g',
                                    initialValue: _carbs,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _carbs = result;
                                  _recalcCaloriesFromMacros();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMacroCard(
                            emoji: '🧈',
                            label: l10n.translate('calorieTracker_fat'),
                            value: _fat,
                            unit: l10n.translate('unit_g'),
                            progress: _macroProgress(
                              _fat,
                              (_goals?.fat ?? 46).toDouble(),
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NutrientEditScreen(
                                    nutrientLabelKey: 'calorieTracker_fat',
                                    unitKey: 'unit_g',
                                    initialValue: _fat,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _fat = result;
                                  _recalcCaloriesFromMacros();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    // Page 2: Fiber, Sugar, Sodium
                    Row(
                      children: [
                        Expanded(
                          child: _buildMacroCard(
                            emoji: '🫐',
                            label: l10n.translate('calorieTracker_fiber'),
                            value: _fiber,
                            unit: l10n.translate('unit_g'),
                            progress: _macroProgress(
                              _fiber,
                              (_goals?.fiber ?? 25).toDouble(),
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NutrientEditScreen(
                                    nutrientLabelKey: 'calorieTracker_fiber',
                                    unitKey: 'unit_g',
                                    initialValue: _fiber,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() => _fiber = result);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMacroCard(
                            emoji: '🍬',
                            label: l10n.translate('calorieTracker_sugar'),
                            value: _sugar,
                            unit: l10n.translate('unit_g'),
                            progress: _macroProgress(
                              _sugar,
                              (_goals?.sugar ?? 25).toDouble(),
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NutrientEditScreen(
                                    nutrientLabelKey: 'calorieTracker_sugar',
                                    unitKey: 'unit_g',
                                    initialValue: _sugar,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() => _sugar = result);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMacroCard(
                            emoji: '🍚',
                            label: l10n.translate('calorieTracker_sodium'),
                            value: _sodium,
                            unit: l10n.translate('unit_mg'),
                            progress: _macroProgress(
                              _sodium,
                              (_goals?.sodium ?? 2300).toDouble(),
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NutrientEditScreen(
                                    nutrientLabelKey: 'calorieTracker_sodium',
                                    unitKey: 'unit_mg',
                                    initialValue: _sodium,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() => _sodium = result);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // Page dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.black : const Color(0xFFE5E5EA),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              l10n.translate('calorieTracker_log'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCard({
    required String emoji,
    required String label,
    required double value,
    required String unit,
    required double progress,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
            _buildEmojiRingWithProgress(emoji, progress),
            const SizedBox(height: 6),
          Text(
            label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
              color: Colors.black54,
                fontWeight: FontWeight.w500,
            ),
          ),
            const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.toStringAsFixed(0)}$unit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined, size: 14, color: Colors.black38),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  double _macroProgress(double consumed, double goal) {
    if (goal <= 0) return 0;
    final p = (consumed / goal).clamp(0.0, 1.0);
    return p;
  }

  double _calorieProgress() {
    // Use goals if available, default 1662 like dashboard
    final double goalCalories = (_goals?.calories ?? 1662).toDouble();
    if (goalCalories <= 0) return 0;
    return (_effectiveCalories / goalCalories).clamp(0.0, 1.0);
  }

  Widget _buildEmojiRing(String emoji) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E5EA), width: 3),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiRingWithProgress(String emoji, double progress) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Track
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEFF1F5), width: 3),
            ),
          ),
          // Progress arc
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                strokeWidth: 3,
                trackColor: const Color(0x00000000),
                progressColor: const Color(0xFFed3272),
              ),
            ),
          ),
          // Inner emoji disk
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.strokeWidth, required this.trackColor, required this.progressColor});
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Optional: draw transparent track (no-op since trackColor alpha 0)
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57079632679, 6.28318530718, false, trackPaint);

    final sweep = 6.28318530718 * progress; // 2*pi * progress
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57079632679, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _MicAnalyzeButton extends StatelessWidget {
  const _MicAnalyzeButton({required this.onTap, required this.isBusy});
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isBusy
              ? null
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                ),
          color: isBusy ? const Color(0xFFed3272).withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFed3272).withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.mic, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _MiniMacroChips extends StatelessWidget {
  const _MiniMacroChips({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.onEdit,
  });

  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final void Function(String macro) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget chip(String label, String value, String macro) {
      return InkWell(
        onTap: () => onEdit(macro),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    final g = l10n.translate('unit_g');
    final mg = l10n.translate('unit_mg');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(l10n.translate('calorieTracker_protein'), '${protein.toStringAsFixed(0)}$g', 'protein'),
          chip(l10n.translate('calorieTracker_carbs'), '${carbs.toStringAsFixed(0)}$g', 'carbs'),
          chip(l10n.translate('calorieTracker_fat'), '${fat.toStringAsFixed(0)}$g', 'fat'),
          chip(l10n.translate('calorieTracker_fiber'), '${fiber.toStringAsFixed(0)}$g', 'fiber'),
          chip(l10n.translate('calorieTracker_sugar'), '${sugar.toStringAsFixed(0)}$g', 'sugar'),
          chip(l10n.translate('calorieTracker_sodium'), '${sodium.toStringAsFixed(0)}$mg', 'sodium'),
        ],
      ),
    );
  }
}