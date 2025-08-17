// lib/services/database_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_crush/models/message_model.dart';
import 'package:rxdart/rxdart.dart';
import 'package:campus_crush/models/user_model.dart';


class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get chat messages between two users
  Stream<List<Message>> getMessages(String user1Id, String user2Id) {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  // --- CORRECTED sendMessage METHOD ---
  Future<void> sendMessage(String senderId, String recipientId, String messageContent) async {
    List<String> userIds = [senderId, recipientId]..sort();
    String chatId = userIds.join('_');

    // Get a reference to the main chat document and the new message document
    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    DocumentReference messageRef = chatRef.collection('messages').doc();

    // Use a batched write to perform multiple operations atomically
    WriteBatch batch = _firestore.batch();

    // 1. Set/update the main chat document first
    batch.set(chatRef, {
      'lastMessage': messageContent,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': userIds,
      'unreadCounts': {
        senderId: 0,
        recipientId: FieldValue.increment(1),
      }
    }, SetOptions(merge: true));

    // 2. Then, create the new message document
    batch.set(messageRef, {
      'senderId': senderId,
      'messageContent': messageContent,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'isEdited': false,
      'isDeleted': false,
    });
    
    // Commit the batch
    await batch.commit();
  }
  
  // Edit an existing message
  Future<void> editMessage(String user1Id, String user2Id, String messageId, String newContent) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');
    final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await messageRef.update({
      'messageContent': newContent,
      'isEdited': true,
    });
  }

  // Unsend a message (marks as deleted)
  Future<void> unsendMessage(String user1Id, String user2Id, String messageId) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');
    final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await messageRef.update({
      'messageContent': 'This message was deleted',
      'isDeleted': true,
      'reactions': {},
    });
  }

  // Add or update an emoji reaction to a message
  Future<void> addReactionToMessage(String user1Id, String user2Id, String messageId, String reactorId, String emoji) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String chatId = userIds.join('_');
    final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await messageRef.update({
      'reactions.$reactorId': emoji
    });
  }

  // Method to mark messages as read
  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    List<String> userIds = [currentUserId, otherUserId]..sort();
    String chatId = userIds.join('_');
    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'unreadCounts.$currentUserId': 0,
    });
  }

  // Get a stream of unread counts
  Stream<Map<String, int>> getUnreadCounts(String currentUserId) {
    return _firestore.collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      Map<String, int> unreadCounts = {};
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? otherUserId = (data['participants'] as List).firstWhere((uid) => uid != currentUserId, orElse: () => null);
        int? count = (data['unreadCounts'] as Map?)?[currentUserId];
        if (otherUserId != null && count != null && count > 0) {
          unreadCounts[otherUserId] = count;
        }
      }
      return unreadCounts;
    });
  }
  
  // Set and get typing status
  Future<void> setTypingStatus(String currentUserId, String otherUserId, bool isTyping) async {
    final chatId = [currentUserId, otherUserId]..sort();
    await _firestore.collection('chats').doc(chatId.join('_')).set({
      'typingStatus': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  Stream<bool> getTypingStatus(String currentUserId, String otherUserId) {
    final chatId = [currentUserId, otherUserId]..sort();
    return _firestore.collection('chats').doc(chatId.join('_')).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data != null && data['typingStatus'] != null) {
        return (data['typingStatus'] as Map)[otherUserId] ?? false;
      }
      return false;
    });
  }
}