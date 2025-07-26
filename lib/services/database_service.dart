import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference for messages
  CollectionReference get _messagesCollection => _firestore.collection('messages');

  // Method to send a message
  Future<void> sendMessage(String senderId, String receiverId, String messageContent) async {
    try {
      // Create a chat room ID by combining sender and receiver UIDs, sorted to ensure consistency
      List<String> ids = [senderId, receiverId];
      ids.sort();
      String chatRoomId = ids.join('_'); // e.g., 'uid1_uid2'

      Message message = Message(
        senderId: senderId,
        receiverId: receiverId,
        messageContent: messageContent,
        timestamp: Timestamp.now(),
      );

      await _messagesCollection.doc(chatRoomId).collection('chats').add(message.toMap());

      // After sending a message, reset typing status
      await setTypingStatus(senderId, receiverId, false);

    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Method to get a stream of messages for a specific chat room
  Stream<List<Message>> getMessages(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _messagesCollection
        .doc(chatRoomId)
        .collection('chats')
        .orderBy('timestamp', descending: true) // Order by timestamp for chronological display
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromSnapshot(doc)).toList();
    });
  }

  // Method to set a user's typing status in a specific chat room
  Future<void> setTypingStatus(String senderId, String receiverId, bool isTyping) async {
    List<String> ids = [senderId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _messagesCollection.doc(chatRoomId).set(
      {
        'typingStatus': {
          senderId: isTyping,
        },
      },
      SetOptions(merge: true), // Merge to update only the typing status for the sender
    );
  }

  // Method to get a stream of the other user's typing status
  Stream<bool> getTypingStatus(String currentUserId, String otherUserId) {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _messagesCollection.doc(chatRoomId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final typingStatus = data['typingStatus'] as Map<String, dynamic>?;
        if (typingStatus != null && typingStatus.containsKey(otherUserId)) {
          return typingStatus[otherUserId] as bool;
        }
      }
      return false; // Default to not typing
    });
  }
}
