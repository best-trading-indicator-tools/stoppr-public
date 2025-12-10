import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/journal/journal_service.dart';
import 'add_journal_entry.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

// Summary: Sanitize user-generated journal text (title/content) before display
// to prevent malformed UTF-16 from reaching Text/TextSpan and crashing.

class JournalFeelingsScreen extends StatefulWidget {
  const JournalFeelingsScreen({super.key});

  @override
  State<JournalFeelingsScreen> createState() => _JournalFeelingsScreenState();
}

class _JournalFeelingsScreenState extends State<JournalFeelingsScreen> {
  final JournalService _journalService = JournalService();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Journal Feelings Screen');
    
    _loadEntries();
    
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

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });

    final entries = await _journalService.getJournalEntries();
    
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }
  
  void _navigateBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            l10n.translate('journalFeelingsScreen_appBarTitle'),
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: _navigateBack,
          ),
          actions: [
            // Help & Info icon
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Color(0xFF1A1A1A),
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'),
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? _buildEmptyState()
                : _buildJournalList(),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            bottom: 20.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _navigateToAddEntry,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ).copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272),
                      Color(0xFFfd5d32),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, size: 24, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'New Journal Entry',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: Color(0xFF666666),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('journalFeelingsScreen_emptyState_title'),
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.translate('journalFeelingsScreen_emptyState_description'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildJournalEntryCard(entry);
      },
    );
  }

  Widget _buildJournalEntryCard(JournalEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    return Dismissible(
      key: Key(entry.id),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              l10n.translate('journalFeelingsScreen_deleteDialog_title'),
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
            content: Text(
              l10n.translate('journalFeelingsScreen_deleteDialog_content'),
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
                child: Text(
                  l10n.translate('common_cancel'),
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
                child: Text(
                  l10n.translate('common_delete'),
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
      },
      onDismissed: (direction) async {
        await _journalService.deleteJournalEntry(entry.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('journalFeelingsScreen_snackbar_entryDeleted')),
            backgroundColor: Color(0xFFed3272),
            duration: Duration(seconds: 2),
          ),
        );
        _loadEntries();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToViewEntry(entry),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.title != null && entry.title!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        TextSanitizer.sanitizeForDisplay(entry.title!),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 18,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    TextSanitizer.sanitizeForDisplay(entry.content),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDate(entry.createdAt),
                    style: TextStyle(
                      color: Color(0xFF666666).withOpacity(0.8),
                      fontSize: 14,
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAddEntry() async {
    Navigator.of(context).pushReplacement(
      BottomToTopPageRoute(
        child: const AddJournalEntryScreen(),
        settings: const RouteSettings(name: '/add_journal_entry'),
      ),
    );
  }

  void _navigateToViewEntry(JournalEntry entry) async {
    Navigator.of(context).pushReplacement(
      BottomToTopPageRoute(
        child: AddJournalEntryScreen(entry: entry),
        settings: const RouteSettings(name: '/view_journal_entry'),
      ),
    );
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Journal Feelings Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }
} 