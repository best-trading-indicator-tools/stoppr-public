import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stoppr/features/community/data/repositories/community_repository.dart';
import '../../../../core/karma/karma_service.dart';

part 'add_post_state.dart';
part 'add_post_cubit.freezed.dart';

class AddPostCubit extends Cubit<AddPostState> {
  final CommunityRepository _communityRepository;
  final KarmaService _karmaService = KarmaService();

  AddPostCubit(this._communityRepository) : super(const AddPostState.initial());

  Future<void> submitPost({
    required String title,
    required String content,
    required String authorId,
    required String authorName,
  }) async {
    if (title.isEmpty || content.isEmpty) {
      emit(const AddPostState.error('Title and content cannot be empty.'));
      // Revert back to initial state after showing error briefly or let UI handle
      await Future.delayed(const Duration(seconds: 2));
       if (state is _Error) { // Check if state is still error before reverting
         emit(const AddPostState.initial());
       }
      return;
    }
    
    emit(const AddPostState.submitting());
    try {
      await _communityRepository.addPost(
        title: title,
        content: content,
        authorId: authorId,
        authorName: authorName,
      );
      
      // Grant karma for posting in community
      await _karmaService.grantKarmaForCommunityPost();
      
      emit(const AddPostState.success());
    } catch (e) {
      emit(AddPostState.error('Failed to submit post: ${e.toString()}'));
      // Option to revert to initial after error
      await Future.delayed(const Duration(seconds: 3));
      if (state is _Error) {
         emit(const AddPostState.initial());
      }
    }
  }
} 