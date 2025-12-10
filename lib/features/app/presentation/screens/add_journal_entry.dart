import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/journal/journal_service.dart';
import 'journal_feelings.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class AddJournalEntryScreen extends StatefulWidget {
  final JournalEntry? entry;
  final bool fromRelapse;

  const AddJournalEntryScreen({
    super.key,
    this.entry,
    this.fromRelapse = false,
  });

  @override
  State<AddJournalEntryScreen> createState() => _AddJournalEntryScreenState();
}

class _AddJournalEntryScreenState extends State<AddJournalEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final JournalService _journalService = JournalService();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isRelapseEntry = false;

  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Add Journal Entry Screen');
    
    _isEditing = widget.entry != null;
    _isRelapseEntry = widget.fromRelapse || (widget.entry?.isRelapseEntry ?? false);
    
    if (_isEditing) {
      _titleController.text = widget.entry!.title ?? '';
      _contentController.text = widget.entry!.content;
    }
    
    // Force status bar icons to dark mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  void _navigateBack({bool result = false}) {
    Navigator.of(context).pushReplacement(
      TopToBottomPageRoute(
        child: const JournalFeelingsScreen(),
        settings: const RouteSettings(name: '/journal_feelings'),
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('journal_enterContent')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String safeTitle = _titleController.text.trim().isEmpty
          ? ''
          : TextSanitizer.sanitizeForDisplay(_titleController.text.trim());
      final String? safeTitleOrNull = safeTitle.isEmpty ? null : safeTitle;
      final String safeContent = TextSanitizer.sanitizeForDisplay(_contentController.text.trim());

      if (_isEditing) {
        await _journalService.updateJournalEntry(
          widget.entry!.copyWith(
            title: safeTitleOrNull,
            content: safeContent,
          ),
        );
      } else if (_isRelapseEntry) {
        await _journalService.addRelapseJournalEntry(
          title: safeTitleOrNull,
          content: safeContent,
        );
      } else {
        await _journalService.addJournalEntry(
          title: safeTitleOrNull,
          content: safeContent,
        );
      }
      
      if (mounted) {
        _navigateBack(result: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('errorMessage_savingJournal').replaceFirst('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  Future<void> _deleteEntry() async {
    if (!_isEditing || widget.entry == null) return;
    
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Delete Entry',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this journal entry? This action cannot be undone.',
          style: TextStyle(
            color: Color(0xFF666666),
            fontFamily: 'ElzaRound',
            fontSize: 18,
            height: 1.4,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFDF8FA),
              foregroundColor: Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Color(0xFFE0E0E0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ) ?? false;
    
    if (!shouldDelete || !mounted) return;
    
    try {
      setState(() {
        _isSaving = true;
      });
      
      await _journalService.deleteJournalEntry(widget.entry!.id);
      
      if (mounted) {
        _navigateBack(result: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('errorMessage_deletingJournal').replaceFirst('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8FA),
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _isEditing ? 'Edit Note' : 'Add Note',
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          leading: TextButton(
            onPressed: () => _navigateBack(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFFed3272),
                fontSize: 16,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          leadingWidth: 80,
          actions: [
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteEntry,
              ),
            TextButton(
              onPressed: _isSaving ? null : _saveEntry,
              child: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFFed3272),
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
            const SizedBox(width: 10),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.translate('journal_titleHint'),
                      hintStyle: TextStyle(
                        color: Color(0xFF666666).withOpacity(0.6),
                        fontSize: 20,
                        fontFamily: 'ElzaRound',
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Content field
                Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    controller: _contentController,
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 18,
                      fontFamily: 'ElzaRound',
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: _isRelapseEntry 
                          ? 'Write about your feelings and experience...'
                          : 'Write your thoughts here...',
                      hintStyle: TextStyle(
                        color: Color(0xFF666666).withOpacity(0.6),
                        fontSize: 18,
                        fontFamily: 'ElzaRound',
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                    expands: true,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 