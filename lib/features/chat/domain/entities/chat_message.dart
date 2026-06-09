// frontend/lib/features/chat/domain/entities/chat_message.dart
import 'package:equatable/equatable.dart';

enum MessageType { text, image, audio, map }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? mediaUrl;
  final String? mapSnippetUrl;
  final Duration? audioDuration;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.isMe,
    this.mediaUrl,
    this.mapSnippetUrl,
    this.audioDuration,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    String? mediaUrl,
    String? mapSnippetUrl,
    Duration? audioDuration,
    bool? isMe,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mapSnippetUrl: mapSnippetUrl ?? this.mapSnippetUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      isMe: isMe ?? this.isMe,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        text,
        type,
        status,
        timestamp,
        mediaUrl,
        mapSnippetUrl,
        audioDuration,
        isMe,
      ];
}
