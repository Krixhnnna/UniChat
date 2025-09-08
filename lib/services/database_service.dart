// lib/services/database_service.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_crush/models/message_model.dart';
// import 'package:rxdart/rxdart.dart';
// import 'package:campus_crush/models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for chat documents to reduce Firebase calls
  final Map<String, DocumentSnapshot> _chatCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Get chat messages between two users with optimized querying
  Stream<List<Message>> getMessages(String user1Id, String user2Id) {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp',
            descending: true) // Back to descending for newest first
        .limit(50) // Limit to last 50 messages for better performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), id: doc.id))
            .toList());
  }

  // Get messages with pagination for better performance
  Stream<List<Message>> getMessagesPaginated(
    String user1Id,
    String user2Id, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');

    Query query = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp',
            descending: true) // Back to descending for newest first
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) =>
            Message.fromMap(doc.data() as Map<String, dynamic>, id: doc.id))
        .toList());
  }

  // Send image message
  Future<void> sendImageMessage(
    String senderId,
    String recipientId,
    String imageUrl, {
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
  }) async {
    final List<String> userIds = [senderId, recipientId]..sort();
    final String chatId = userIds.join('_');

    final DocumentReference chatRef =
        _firestore.collection('chats').doc(chatId);
    final CollectionReference messagesRef = chatRef.collection('messages');

    // 1) Ensure chat doc exists/updated first
    await _firestore.runTransaction((transaction) async {
      final chatDoc = await transaction.get(chatRef);

      Map<String, dynamic> chatData = {};
      Map<String, dynamic> unreadCounts = {};

      if (chatDoc.exists) {
        chatData = chatDoc.data() as Map<String, dynamic>;
        unreadCounts =
            Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});
      }

      // Update unread counts properly
      unreadCounts[senderId] = 0; // Sender always has 0 unread
      unreadCounts[recipientId] =
          (unreadCounts[recipientId] ?? 0) + 1; // Increment recipient count

      final updatedChatData = {
        'participants': userIds,
        'lastMessage': '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
      };

      if (chatDoc.exists) {
        transaction.update(chatRef, updatedChatData);
      } else {
        transaction.set(chatRef, updatedChatData);
      }
    });

    // 2) Then write the message doc
    final messageData = {
      'senderId': senderId,
      'content': '',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'imageUrl': imageUrl,
    };

    // Add reply fields if this is a reply
    if (replyToMessageId != null) {
      messageData['replyToMessageId'] = replyToMessageId;
      if (replyToContent != null)
        messageData['replyToContent'] = replyToContent;
      if (replyToSenderId != null)
        messageData['replyToSenderId'] = replyToSenderId;
    }

    await messagesRef.add(messageData);

    // Clear cache for this chat
    _chatCache.remove(chatId);
  }

  // sendMessage in two steps so Firestore rules can validate against chat doc that already exists
  Future<void> sendMessage(
    String senderId,
    String recipientId,
    String messageContent, {
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
  }) async {
    final List<String> userIds = [senderId, recipientId]..sort();
    final String chatId = userIds.join('_');

    final DocumentReference chatRef =
        _firestore.collection('chats').doc(chatId);
    final CollectionReference messagesRef = chatRef.collection('messages');

    // 1) Ensure chat doc exists/updated first
    await _firestore.runTransaction((transaction) async {
      final chatDoc = await transaction.get(chatRef);

      Map<String, dynamic> chatData = {};
      Map<String, dynamic> unreadCounts = {};

      if (chatDoc.exists) {
        chatData = chatDoc.data() as Map<String, dynamic>;
        unreadCounts =
            Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});
      }

      // Update unread counts properly
      unreadCounts[senderId] = 0; // Sender always has 0 unread
      // Increment recipient count (Cloud Function no longer does this to prevent double counting)
      unreadCounts[recipientId] =
          (unreadCounts[recipientId] ?? 0) + 1; // Increment recipient count

      final updatedChatData = {
        'participants': userIds,
        'lastMessage': messageContent,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
      };

      if (chatDoc.exists) {
        transaction.update(chatRef, updatedChatData);
      } else {
        transaction.set(chatRef, updatedChatData);
      }
    });

    // 2) Then write the message doc (rules can now read participants from chat)
    final messageData = {
      'senderId': senderId,
      'content': messageContent,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'imageUrl': null,
    };

    // Add reply fields if this is a reply
    if (replyToMessageId != null) {
      messageData['replyToMessageId'] = replyToMessageId;
      if (replyToContent != null)
        messageData['replyToContent'] = replyToContent;
      if (replyToSenderId != null)
        messageData['replyToSenderId'] = replyToSenderId;
    }

    await messagesRef.add(messageData);

    // Clear cache for this chat
    _chatCache.remove(chatId);
  }

  // Get chat document with caching
  Future<DocumentSnapshot?> getChatDocument(String chatId) async {
    // Check cache first
    final cached = _chatCache[chatId];
    final timestamp = _cacheTimestamps[chatId];

    if (cached != null &&
        timestamp != null &&
        DateTime.now().difference(timestamp) < _cacheExpiry) {
      return cached;
    }

    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) {
        _chatCache[chatId] = doc;
        _cacheTimestamps[chatId] = DateTime.now();
      }
      return doc;
    } catch (e) {
      print('Error getting chat document: $e');
      return null;
    }
  }

  // Get all chats for a user with optimized querying
  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'chatId': doc.id,
                  'data': doc.data(),
                })
            .toList());
  }

  // Mark messages as read with transaction for better consistency
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // First, get the chat document to check current unread count
        final chatRef = _firestore.collection('chats').doc(chatId);
        final chatDoc = await transaction.get(chatRef);

        if (!chatDoc.exists) return;

        final chatData = chatDoc.data() as Map<String, dynamic>;
        final unreadCounts =
            chatData['unreadCounts'] as Map<String, dynamic>? ?? {};
        final currentUnreadCount = unreadCounts[userId] as int? ?? 0;

        // Only proceed if there are actually unread messages
        if (currentUnreadCount > 0) {
          // Reset unread count to 0
          transaction.update(chatRef, {
            'unreadCounts.$userId': 0,
          });

          // Get and update unread messages
          final messagesRef =
              _firestore.collection('chats').doc(chatId).collection('messages');
          final unreadMessages = await messagesRef
              .where('senderId', isNotEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

          for (final doc in unreadMessages.docs) {
            transaction.update(doc.reference, {'isRead': true});
          }

          print(
              'Marked ${unreadMessages.docs.length} messages as read for user $userId in chat $chatId');
        }
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<String> _uploadChatAudio(String chatId, File file) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chats')
        .child(chatId)
        .child('audio')
        .child('${DateTime.now().millisecondsSinceEpoch}.m4a');
    final task = await storageRef.putFile(
        file, SettableMetadata(contentType: 'audio/m4a'));
    final url = await task.ref.getDownloadURL();
    return url;
  }

  Future<void> sendAudioMessage(
    String senderId,
    String recipientId,
    File audioFile,
    int durationMs,
  ) async {
    final List<String> userIds = [senderId, recipientId]..sort();
    final String chatId = userIds.join('_');

    final DocumentReference chatRef =
        _firestore.collection('chats').doc(chatId);
    final CollectionReference messagesRef = chatRef.collection('messages');

    // Upload audio file
    final audioUrl = await _uploadChatAudio(chatId, audioFile);

    // Update chat document
    await _firestore.runTransaction((transaction) async {
      final chatDoc = await transaction.get(chatRef);

      Map<String, dynamic> unreadCounts = {};

      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        unreadCounts =
            Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});
      }

      // Update unread counts properly
      unreadCounts[senderId] = 0; // Sender always has 0 unread
      unreadCounts[recipientId] =
          (unreadCounts[recipientId] ?? 0) + 1; // Increment recipient count

      final updatedChatData = {
        'participants': userIds,
        'lastMessage': '🎵 Audio message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
      };

      if (chatDoc.exists) {
        transaction.update(chatRef, updatedChatData);
      } else {
        transaction.set(chatRef, updatedChatData);
      }
    });

    // Add audio message
    await messagesRef.add({
      'senderId': senderId,
      'content': '',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'audioUrl': audioUrl,
      'audioDuration': durationMs,
    });

    // Clear cache for this chat
    _chatCache.remove(chatId);
  }

  // Clear expired cache entries
  void _cleanupCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheExpiry)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _chatCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  // Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    _cleanupCache();
    return {
      'cacheSize': _chatCache.length,
      'cacheEntries': _chatCache.keys.toList(),
      'timestamps':
          _cacheTimestamps.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }

  // Edit an existing message
  Future<void> editMessage(String user1Id, String user2Id, String messageId,
      String newContent) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await messageRef.update({
      'content': newContent,
    });

    // Clear cache for this chat
    _chatCache.remove(chatId);
  }

  // Unsend a message (marks as deleted)
  Future<void> unsendMessage(
      String user1Id, String user2Id, String messageId) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await messageRef.update({
      'content': 'This message was deleted',
    });

    // Clear cache for this chat
    _chatCache.remove(chatId);
  }

  // Delete a message completely from Firebase
  Future<void> deleteMessage(
      String user1Id, String user2Id, String messageId) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await messageRef.delete();

    // Clear cache for this chat
    _chatCache.remove(chatId);
  }

  // Get user document for presence
  Stream<Map<String, dynamic>?> getUserDocument(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => snap.data());
  }

  // Get user's online status
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data != null && data['isOnline'] != null) {
        return data['isOnline'] as bool;
      }
      return false;
    });
  }

  // Set and get typing status
  Future<void> setTypingStatus(
      String currentUserId, String otherUserId, bool isTyping) async {
    final chatId = [currentUserId, otherUserId]..sort();
    await _firestore.collection('chats').doc(chatId.join('_')).set({
      'typingStatus': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  Stream<bool> getTypingStatus(String currentUserId, String otherUserId) {
    final chatId = [currentUserId, otherUserId]..sort();
    return _firestore
        .collection('chats')
        .doc(chatId.join('_'))
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data != null && data['typingStatus'] != null) {
        return (data['typingStatus'] as Map)[otherUserId] ?? false;
      }
      return false;
    });
  }
}
