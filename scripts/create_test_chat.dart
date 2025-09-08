import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Test user IDs (replace with actual user IDs from your app)
  String user1Id = 'test_user_1';
  String user2Id = 'test_user_2';

  // Create chat ID
  List<String> userIds = [user1Id, user2Id]..sort();
  String chatId = userIds.join('_');

  print('Creating chat document with ID: $chatId');

  try {
    // Create the chat document
    await firestore.collection('chats').doc(chatId).set({
      'participants': userIds,
      'lastMessage': 'Test message',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {
        user1Id: 0,
        user2Id: 0,
      },
    });

    print('✅ Chat document created successfully!');

    // Create a test message
    await firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': user1Id,
      'content': 'Hello! This is a test message.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'imageUrl': null,
    });

    print('✅ Test message created successfully!');
  } catch (e) {
    print('❌ Error creating chat: $e');
  }

  exit(0);
}
