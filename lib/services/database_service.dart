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

  // Send a new message
  Future<void> sendMessage(String senderId, String recipientId, String messageContent) async {
    List<String> userIds = [senderId, recipientId]..sort();
    String chatId = userIds.join('_');

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': senderId,
      'messageContent': messageContent,
      'timestamp': FieldValue.serverTimestamp(),
    });

    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.set({
      'lastMessage': messageContent,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': userIds,
      'unreadCounts': {
        senderId: 0,
        recipientId: FieldValue.increment(1),
      }
    }, SetOptions(merge: true));
  }

  // Method to mark messages as read for a specific user
  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    List<String> userIds = [currentUserId, otherUserId]..sort();
    String chatId = userIds.join('_');

    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'unreadCounts.$currentUserId': 0,
    });
  }

  // New method to get a stream of unread counts for all matches
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
  
  // New method to set a user's typing status
  Future<void> setTypingStatus(String currentUserId, String otherUserId, bool isTyping) async {
    final chatId = [currentUserId, otherUserId]..sort();
    await _firestore.collection('chats').doc(chatId.join('_')).set({
      'typingStatus': {
        currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  // New method to get a user's typing status
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