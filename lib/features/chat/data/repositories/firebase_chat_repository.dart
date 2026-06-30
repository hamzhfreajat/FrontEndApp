// frontend/lib/features/chat/data/repositories/firebase_chat_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/inbox_thread.dart';
import '../../../../services/api_service.dart';
import 'package:flutter/foundation.dart';

class FirebaseChatRepository {
  final FirebaseFirestore _firestore;
  final ApiService _apiService;

  FirebaseChatRepository({
    FirebaseFirestore? firestore,
    ApiService? apiService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _apiService = apiService ?? ApiService();

  // Helper to generate a consistent chat ID between two users for a specific ad
  String _getChatId(String adId, String currentUserId, String otherUserId) {
    if (adId == 'welcome' || adId == 'support') {
      final user = currentUserId == 'admin' ? otherUserId : currentUserId;
      return 'welcome_admin_$user';
    }
    // Sort user IDs to ensure the same chat ID regardless of who started it
    final users = [currentUserId, otherUserId]..sort();
    return '${adId}_${users[0]}_${users[1]}';
  }

  Stream<List<ChatMessage>> getChatMessages(String adId, String currentUserId, String otherUserId) {
    final chatId = _getChatId(adId, currentUserId, otherUserId);
    
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        
        MessageType messageType;
        switch (data['type']) {
          case 'image':
            messageType = MessageType.image;
            break;
          case 'location':
            messageType = MessageType.map;
            break;
          case 'audio':
            messageType = MessageType.audio;
            break;
          default:
            messageType = MessageType.text;
        }

        MessageStatus status;
        switch (data['status']) {
          case 'read':
            status = MessageStatus.read;
            break;
          case 'delivered':
            status = MessageStatus.delivered;
            break;
          case 'sent':
            status = MessageStatus.sent;
            break;
          default:
            status = MessageStatus.sending;
        }

        return ChatMessage(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          text: data['text'] ?? '',
          type: messageType,
          mediaUrl: data['mediaUrl'],
          audioDuration: data['audioDuration'] != null ? Duration(seconds: data['audioDuration']) : null,
          status: status,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isMe: data['senderId'] == currentUserId,
        );
      }).toList();
    });
  }

  Future<void> sendMessage({
    required String adId,
    required String adTitle,
    required String adPrice,
    required String adImageUrl,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    String? currentUserPhone,
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
    String? otherUserPhone,
    required ChatMessage message,
  }) async {
    final chatId = _getChatId(adId, currentUserId, otherUserId);

    // Save message to Firestore
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set({
      'senderId': message.senderId,
      'text': message.text,
      'type': message.type.toString().split('.').last,
      'mediaUrl': message.mediaUrl,
      'audioDuration': message.audioDuration?.inSeconds,
      'status': 'sent', // Firestore messages are sent
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update the parent chat document with latest info for inbox lists
    await _firestore.collection('chats').doc(chatId).set({
      'adId': adId,
      'adTitle': adTitle,
      'adPrice': adPrice,
      'adImageUrl': adImageUrl,
      'participants': [currentUserId, otherUserId],
      'users': {
        currentUserId: {
          'name': currentUserName,
          'avatar': currentUserAvatar,
          'phone': currentUserPhone,
          'unreadCount': 0,
        },
        otherUserId: {
          'name': otherUserName,
          'avatar': otherUserAvatar,
          'phone': otherUserPhone,
          'unreadCount': FieldValue.increment(1),
        }
      },
      'lastMessage': message.type == MessageType.text 
          ? message.text 
          : (message.type == MessageType.audio ? '🎤 مقطع صوتي' : '📷 صورة'),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUserId,
    }, SetOptions(merge: true));

    // Send push notification via backend
    try {
      final targetUserIdInt = int.tryParse(otherUserId);
      if (targetUserIdInt != null) {
        await _apiService.sendChatAlert(
          targetUserId: targetUserIdInt,
          senderName: currentUserName,
          messagePreview: message.type == MessageType.text 
              ? message.text 
              : (message.type == MessageType.audio ? '🎤 أرسل مقطع صوتي' : '📷 أرسل صورة'),
          adId: adId,
          adTitle: adTitle,
          chatId: chatId,
          messageId: message.id,
        );
      }
    } catch (e) {
      debugPrint('Failed to trigger push notification: $e');
    }

    // Auto-reply logic for customer support
    if (otherUserId == 'admin') {
      _handleSupportAutoReply(
        chatId: chatId,
        currentUserId: currentUserId,
      );
    }
  }

  Future<void> _handleSupportAutoReply({
    required String chatId,
    required String currentUserId,
  }) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      bool shouldSendAutoReply = true;
      if (chatDoc.exists) {
        final data = chatDoc.data();
        if (data != null && data.containsKey('lastAutoReplyTime')) {
          final lastAutoReplyTime = (data['lastAutoReplyTime'] as Timestamp?)?.toDate();
          // Send auto-reply only if it's been more than 2 hours since the last one
          if (lastAutoReplyTime != null && DateTime.now().difference(lastAutoReplyTime).inHours < 2) {
            shouldSendAutoReply = false;
          }
        }
      }

      if (shouldSendAutoReply) {
        // Natural delay
        await Future.delayed(const Duration(seconds: 1));
        
        final autoReplyMessageId = 'auto_${DateTime.now().millisecondsSinceEpoch}';
        const autoReplyText = 'مرحباً بك! 👋\nفريق خدمة العملاء استلم رسالتك، وسيقوم أحد ممثلينا بالرد عليك في أقرب وقت ممكن. شكراً لتواصلك معنا.';
        
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(autoReplyMessageId)
            .set({
          'senderId': 'admin',
          'text': autoReplyText,
          'type': 'text',
          'mediaUrl': null,
          'status': 'sent',
          'timestamp': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('chats').doc(chatId).set({
          'lastMessage': autoReplyText,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': 'admin',
          'lastAutoReplyTime': FieldValue.serverTimestamp(),
          'users': {
            currentUserId: {
              'unreadCount': FieldValue.increment(1),
            },
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to send auto-reply: $e');
    }
  }

  Future<void> markChatAsRead(String adId, String currentUserId, String otherUserId, {String? currentUserName, String? otherUserName}) async {
    final chatId = _getChatId(adId, currentUserId, otherUserId);
    final batch = _firestore.batch();
    
    final chatRef = _firestore.collection('chats').doc(chatId);

    final currentUserData = <String, dynamic>{
      'unreadCount': 0,
    };
    if (currentUserName != null && currentUserName.isNotEmpty && currentUserName != 'مستخدم') {
      currentUserData['name'] = currentUserName;
    }

    final otherUserData = <String, dynamic>{};
    if (otherUserName != null && otherUserName.isNotEmpty && otherUserName != 'مستخدم' && otherUserName != 'LOADING_NAME') {
      otherUserData['name'] = otherUserName;
    }

    final usersMap = <String, dynamic>{
      currentUserId: currentUserData,
    };
    if (otherUserData.isNotEmpty) {
      usersMap[otherUserId] = otherUserData;
    }

    batch.set(chatRef, {
      'users': usersMap
    }, SetOptions(merge: true));

    // Mark messages sent by the other user as read
    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('status', isNotEqualTo: 'read')
          .get();
          
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  Stream<int> getTotalUnreadCount(String userId) {
    if (userId.isEmpty) return Stream.value(0);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final users = doc.data()['users'] as Map<String, dynamic>? ?? {};
        final myUser = users[userId] as Map<String, dynamic>? ?? {};
        total += (myUser['unreadCount'] as int?) ?? 0;
      }
      return total;
    });
  }

  // Handle typing indicator
  Stream<bool> getTypingStatus(String adId, String currentUserId, String otherUserId) {
    final chatId = _getChatId(adId, currentUserId, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      if (data == null) return false;
      final typingMap = data['typing'] as Map<String, dynamic>?;
      if (typingMap == null) return false;
      return typingMap[otherUserId] == true;
    });
  }

  Future<void> setTypingStatus(String adId, String currentUserId, String otherUserId, bool isTyping) async {
    final chatId = _getChatId(adId, currentUserId, otherUserId);
    await _firestore.collection('chats').doc(chatId).set({
      'typing': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  // Stream Inbox Threads
  Stream<List<InboxThread>> getInboxThreads(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final threads = snapshot.docs.map((doc) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');
        
        final users = data['users'] as Map<String, dynamic>? ?? {};
        final otherUser = users[otherUserId] as Map<String, dynamic>? ?? {};
        final myUser = users[userId] as Map<String, dynamic>? ?? {};
        
        return InboxThread(
          threadId: doc.id,
          adId: data['adId'] ?? '',
          adTitle: data['adTitle'] ?? 'إعلان',
          adPrice: data['adPrice'] ?? '',
          adImageUrl: data['adImageUrl'] ?? '',
          otherUserId: otherUserId,
          otherUserName: otherUser['name'] ?? 'مستخدم',
          otherUserAvatar: otherUser['avatar'] ?? 'https://cdn-icons-png.freepik.com/512/3135/3135715.png',
          otherUserPhone: otherUser['phone'],
          lastMessageText: data['lastMessage'] ?? '',
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          unreadCount: (myUser['unreadCount'] as int?) ?? 0,
          isSeller: data['sellerId'] == userId,
          isFavorite: myUser['isFavorite'] ?? false,
        );
      }).toList();
      
      // Sort locally by lastMessageTime descending
      threads.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return threads;
    });
  }

  // Toggle favorite status
  Future<void> toggleFavoriteStatus(String chatId, String userId, bool isFavorite) async {
    await _firestore.collection('chats').doc(chatId).set({
      'users': {
        userId: {
          'isFavorite': isFavorite
        }
      }
    }, SetOptions(merge: true));
  }

  // Delete chat
  Future<void> deleteChat(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });
  }
}
