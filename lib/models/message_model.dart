// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String messageContent;
  final Timestamp timestamp;
  final Map<String, String> reactions;
  final bool isEdited; // ADDED: To track if a message has been edited
  final bool isDeleted; // ADDED: To track if a message is "unsent"

  Message({
    required this.id,
    required this.senderId,
    required this.messageContent,
    required this.timestamp,
    this.reactions = const {},
    this.isEdited = false, // ADDED
    this.isDeleted = false, // ADDED
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      messageContent: data['messageContent'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      isEdited: data['isEdited'] ?? false, // ADDED
      isDeleted: data['isDeleted'] ?? false, // ADDED
    );
  }
}