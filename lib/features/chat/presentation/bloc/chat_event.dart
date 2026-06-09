// frontend/lib/features/chat/presentation/bloc/chat_event.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatHistory extends ChatEvent {
  final String adId;
  const LoadChatHistory(this.adId);

  @override
  List<Object?> get props => [adId];
}

class SendMessage extends ChatEvent {
  final String text;
  final MessageType type;
  final String? payloadUrl;
  final Duration? audioDuration;
  const SendMessage({required this.text, this.type = MessageType.text, this.payloadUrl, this.audioDuration});

  @override
  List<Object?> get props => [text, type, payloadUrl, audioDuration];
}

class TypingIndicatorChanged extends ChatEvent {
  final bool isTyping;
  const TypingIndicatorChanged(this.isTyping);

  @override
  List<Object?> get props => [isTyping];
}
