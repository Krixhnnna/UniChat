// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String messageContent;
  final Timestamp timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.messageContent,
    required this.timestamp,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      messageContent: data['messageContent'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}