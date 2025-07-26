import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String receiverId;
  final String messageContent;
  final Timestamp timestamp;

  Message({
    required this.senderId,
    required this.receiverId,
    required this.messageContent,
    required this.timestamp,
  });

  // Factory constructor to create a Message from a Firestore DocumentSnapshot
  factory Message.fromSnapshot(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Message(
      senderId: snapshot['senderId'] ?? '',
      receiverId: snapshot['receiverId'] ?? '',
      messageContent: snapshot['messageContent'] ?? '',
      timestamp: snapshot['timestamp'] ?? Timestamp.now(),
    );
  }

  // Method to convert a Message instance into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'messageContent': messageContent,
      'timestamp': timestamp,
    };
  }
}
