// frontend/lib/features/chat/presentation/bloc/chat_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/repositories/firebase_chat_repository.dart';
import '../../../../providers/notification_provider.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirebaseChatRepository repository;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatar;
  final String? currentUserPhone;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final String? otherUserPhone;
  final String adTitle;
  final String adPrice;
  final String adImageUrl;

  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<bool>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  ChatBloc({
    required this.repository,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatar,
    this.currentUserPhone,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.otherUserPhone,
    required this.adTitle,
    required this.adPrice,
    required this.adImageUrl,
  }) : super(ChatInitial()) {
    on<LoadChatHistory>(_onLoadChatHistory);
    on<SendMessage>(_onSendMessage);
    on<TypingIndicatorChanged>(_onTypingIndicatorChanged);
    on<_UpdateChatMessages>(_onUpdateChatMessages);
    on<_UpdateTypingStatus>(_onUpdateTypingStatus);
    on<_ChatStreamError>(_onChatStreamError);
  }

  void _onUpdateChatMessages(_UpdateChatMessages event, Emitter<ChatState> emit) {
    List<ChatMessage> messages = List.from(event.messages);
    
    // Inject a local welcome message for support chat if not present
    if (event.adId == 'support' || event.adId == 'welcome') {
      final bool hasWelcomeMessage = messages.any((m) => m.text == 'مرحباً بك! نحن هنا لمساعدتك' || m.text.contains('نحن هنا لمساعدتك'));
      if (!hasWelcomeMessage) {
        messages.add(
          ChatMessage(
            id: 'welcome_msg_fixed',
            senderId: 'admin',
            text: 'مرحباً بك! نحن هنا لمساعدتك',
            type: MessageType.text,
            status: MessageStatus.read,
            timestamp: DateTime.fromMillisecondsSinceEpoch(0), // Ensure it's always at the top (oldest)
            isMe: false,
          )
        );
        // Ensure the list stays sorted descending by time (newest first)
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    }

    if (state is ChatLoaded) {
      emit((state as ChatLoaded).copyWith(messages: messages, adId: event.adId));
    } else {
      emit(ChatLoaded(messages: messages, adId: event.adId)); 
    }
  }

  void _onUpdateTypingStatus(_UpdateTypingStatus event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      emit((state as ChatLoaded).copyWith(isOtherUserTyping: event.isTyping));
    }
  }

  void _onChatStreamError(_ChatStreamError event, Emitter<ChatState> emit) {
    // Ignore stream errors to prevent the UI from collapsing. 
    // Firebase will automatically try to reconnect.
    // We can log it safely.
    // emit(ChatError(event.error)); 
  }

  Future<void> _onLoadChatHistory(LoadChatHistory event, Emitter<ChatState> emit) async {
    emit(ChatLoading());

    // Cancel old subscriptions if any
    await _messagesSubscription?.cancel();
    await _typingSubscription?.cancel();

    // Listen to messages
    _messagesSubscription = repository
        .getChatMessages(event.adId, currentUserId, otherUserId)
        .listen((messages) {
      add(_UpdateChatMessages(messages, event.adId));
      repository.markChatAsRead(
        event.adId, 
        currentUserId, 
        otherUserId,
        currentUserName: currentUserName,
        otherUserName: otherUserName,
      );
    }, onError: (error) {
      add(_ChatStreamError("Failed to load messages: $error"));
    });

    // Listen to typing status
    _typingSubscription = repository
        .getTypingStatus(event.adId, currentUserId, otherUserId)
        .listen((isTyping) {
      add(_UpdateTypingStatus(isTyping));
    });

    // Fallback: Listen to real-time WebSocket push notifications to instantly update UI 
    // even if the Firestore network drops.
    await _wsSubscription?.cancel();
    _wsSubscription = NotificationProvider.wsMessageStream.stream.listen((data) {
      if (data['type'] == 'chat_message' && data['reference_id']?.toString() == event.adId) {
        final state = this.state;
        if (state is ChatLoaded) {
          final newMessage = ChatMessage(
            id: 'ws_${data['id']}',
            senderId: otherUserId,
            text: data['body'] ?? '',
            type: MessageType.text,
            status: MessageStatus.delivered,
            timestamp: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
            isMe: false,
          );
          
          // Check if we don't already have this message from Firestore
          if (!state.messages.any((m) => m.text == newMessage.text && !m.isMe && 
              m.timestamp.difference(newMessage.timestamp).inSeconds.abs() < 5)) {
            final updatedList = List<ChatMessage>.from(state.messages)..insert(0, newMessage);
            add(_UpdateChatMessages(updatedList, event.adId));
          }
        }
      }
    });

    // The ChatLoaded state will be emitted automatically when the stream returns data
    // whether it's empty or full.
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      
      final newMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID until Firestore replaces it or we use uuid
        senderId: currentUserId,
        text: event.text,
        type: event.type,
        mediaUrl: event.payloadUrl,
        audioDuration: event.audioDuration,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        isMe: true,
      );

      // Optimistic Update
      emit(currentState.copyWith(messages: [newMessage, ...currentState.messages]));

      await repository.sendMessage(
        adId: currentState.adId,
        adTitle: adTitle,
        adPrice: adPrice,
        adImageUrl: adImageUrl,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        currentUserPhone: currentUserPhone,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
        otherUserPhone: otherUserPhone,
        message: newMessage,
      );
    }
  }

  Future<void> _onTypingIndicatorChanged(TypingIndicatorChanged event, Emitter<ChatState> emit) async {
    if (state is ChatLoaded) {
      await repository.setTypingStatus(
        (state as ChatLoaded).adId,
        currentUserId,
        otherUserId,
        event.isTyping,
      );
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _wsSubscription?.cancel();
    return super.close();
  }
}

// Internal events for stream updates
class _UpdateChatMessages extends ChatEvent {
  final List<ChatMessage> messages;
  final String adId;
  const _UpdateChatMessages(this.messages, this.adId);
  @override
  List<Object> get props => [messages];
}

class _UpdateTypingStatus extends ChatEvent {
  final bool isTyping;
  const _UpdateTypingStatus(this.isTyping);
  @override
  List<Object> get props => [isTyping];
}

class _ChatStreamError extends ChatEvent {
  final String error;
  const _ChatStreamError(this.error);
  @override
  List<Object> get props => [error];
}
