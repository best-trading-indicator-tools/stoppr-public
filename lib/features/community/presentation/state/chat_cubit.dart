import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stoppr/features/community/data/models/chat_message_model.dart';
import 'package:stoppr/features/community/data/repositories/chat_repository.dart';

part 'chat_cubit.freezed.dart';

@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.loaded(List<ChatMessage> messages) = _Loaded;
  const factory ChatState.error(String message) = _Error;
}

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repository;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  ChatCubit(this._repository) : super(const ChatState.initial()) {
    loadMessages();
  }

  ChatRepository get repository => _repository;

  void loadMessages() {
    emit(const ChatState.loading());
    
    _messagesSubscription?.cancel();
    _messagesSubscription = _repository.getChatMessages().listen(
      (messages) {
        emit(ChatState.loaded(messages));
      },
      onError: (error) {
        emit(ChatState.error(error.toString()));
      },
    );
  }

  Future<void> sendMessage(String text) async {
    try {
      await _repository.sendMessage(text);
    } catch (e) {
      emit(ChatState.error('Failed to send message: ${e.toString()}'));
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
    } catch (e) {
      emit(ChatState.error('Failed to delete message: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
} 