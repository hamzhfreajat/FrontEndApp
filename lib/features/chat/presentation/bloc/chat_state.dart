// frontend/lib/features/chat/presentation/bloc/chat_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool isOtherUserTyping;
  final String adId;

  const ChatLoaded({
    required this.messages,
    required this.adId,
    this.isOtherUserTyping = false,
  });

  ChatLoaded copyWith({
    List<ChatMessage>? messages,
    bool? isOtherUserTyping,
    String? adId,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
      adId: adId ?? this.adId,
    );
  }

  @override
  List<Object?> get props => [messages, isOtherUserTyping, adId];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
