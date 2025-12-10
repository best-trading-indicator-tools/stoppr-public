import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/features/community/data/repositories/community_repository.dart';
import 'package:stoppr/features/community/presentation/state/add_post_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class AddPostScreen extends StatelessWidget {
  const AddPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to dark for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));
    
    return BlocProvider(
      create: (context) => AddPostCubit(context.read<CommunityRepository>()),
      child: const _AddPostView(),
    );
  }
}

class _AddPostView extends StatefulWidget {
  const _AddPostView();

  @override
  State<_AddPostView> createState() => _AddPostViewState();
}

class _AddPostViewState extends State<_AddPostView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final UserRepository _userRepository = UserRepository();
  String? _userFirstName;
  bool _isLoadingUserProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _isLoadingUserProfile = true;
      });
      
      try {
        final userProfile = await _userRepository.getUserProfile(currentUser.uid);
        
        setState(() {
          _userFirstName = userProfile?['firstName'] as String?;
          _isLoadingUserProfile = false;
        });
        
        debugPrint("Loaded user profile with firstName: $_userFirstName");
        
        // If we have a valid first name, update all previous posts
        if (_userFirstName != null && _userFirstName!.isNotEmpty) {
          _updatePreviousPosts(currentUser.uid, _userFirstName!);
        }
      } catch (e) {
        debugPrint("Error loading user profile: $e");
        setState(() {
          _isLoadingUserProfile = false;
        });
      }
    }
  }
  
  // Update all previous posts made by this user to use their first name
  Future<void> _updatePreviousPosts(String userId, String firstName) async {
    try {
      debugPrint("Updating previous posts to use first name: $firstName");
      
      // Get all posts by this user
      final postsQuery = FirebaseFirestore.instance
          .collection('community_posts')
          .where('authorId', isEqualTo: userId);
          
      final postsSnapshot = await postsQuery.get();
      
      if (postsSnapshot.docs.isNotEmpty) {
        debugPrint("Found ${postsSnapshot.docs.length} posts by user $userId");
        
        // Use a batch to update all posts
        final batch = FirebaseFirestore.instance.batch();
        int updatedCount = 0;
        
        for (final postDoc in postsSnapshot.docs) {
          final currentData = postDoc.data() as Map<String, dynamic>?;
          final currentName = currentData?['authorName'] as String?;
          
          // Update only if name is different
          if (currentName != firstName) {
            batch.update(postDoc.reference, {'authorName': firstName});
            updatedCount++;
          }
        }
        
        // Commit the batch if there are updates
        if (updatedCount > 0) {
          await batch.commit();
          debugPrint("Updated authorName for $updatedCount posts");
        }
      }
    } catch (e) {
      debugPrint("Error updating previous posts: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submitPost(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Generate anonymous ID if user is not logged in
      final String authorId = currentUserId ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
      
      final String authorNameRaw = _userFirstName?.isNotEmpty == true
          ? _userFirstName!
          : (FirebaseAuth.instance.currentUser?.displayName ?? 
             FirebaseAuth.instance.currentUser?.email ?? 
             'Anonymous');
      final String authorName = TextSanitizer.sanitizeForDisplay(authorNameRaw);

      final String safeTitle = TextSanitizer.sanitizeForDisplay(_titleController.text.trim());
      final String safeContent = TextSanitizer.sanitizeForDisplay(_contentController.text.trim());

      context.read<AddPostCubit>().submitPost(
            title: safeTitle,
            content: safeContent,
            authorId: authorId,
            authorName: authorName,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryBackgroundColor = const Color(0xFFFBFBFB); // Updated neutral background
    final Color primaryTextColor = const Color(0xFF1A1A1A); // Brand dark text
    final Color secondaryTextColor = const Color(0xFF666666); // Brand gray text
    final Color accentColor = const Color(0xFFed3272); // Brand pink
    final Color inputBackgroundColor = Colors.white; // White input background

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: primaryBackgroundColor,
        appBar: AppBar(
          backgroundColor: primaryBackgroundColor,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('createPost_title'),
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600, 
              fontSize: 18,
              color: primaryTextColor,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.close, color: primaryTextColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocListener<AddPostCubit, AddPostState>(
          listener: (context, state) {
            state.maybeWhen(
              success: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!
                          .translate('addPost_successMessage'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    backgroundColor: const Color(0xFFed3272), // Brand pink
                    behavior: SnackBarBehavior.fixed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
                Navigator.of(context).pop(); // Close screen on success
              },
              error: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    backgroundColor: const Color(0xFFE53E3E), // Consistent red
                    behavior: SnackBarBehavior.fixed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              orElse: () {}, // Do nothing for initial or submitting states
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Title input block
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: inputBackgroundColor,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                    ),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 24,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.translate('addPost_titleHint'),
                        hintStyle: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 24,
                          fontFamily: 'ElzaRound',
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Content input block
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: inputBackgroundColor,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                      ),
                      child: TextField(
                        controller: _contentController,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 20,
                          fontFamily: 'ElzaRound',
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.translate('addPost_contentHint'),
                          hintStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 20,
                            fontFamily: 'ElzaRound',
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  
                  // Karma text - green and bold on one line
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'You now get awarded karma for good posts.',
                      style: TextStyle(
                        color: const Color(0xFF4CAF50), // Green that works on white background
                        fontSize: 14,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w700, // Bold
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  
                  // Post button - less wide and higher
                  BlocBuilder<AddPostCubit, AddPostState>(
                    builder: (context, state) {
                      final isSubmitting = state.maybeWhen(
                        submitting: () => true,
                        orElse: () => false,
                      );
                      
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                        margin: const EdgeInsets.only(bottom: 24.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272), // Brand pink
                                Color(0xFFfd5d32), // Brand orange
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: ElevatedButton(
                            onPressed: isSubmitting 
                                ? null 
                                : () => _submitPost(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 30,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Post',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 