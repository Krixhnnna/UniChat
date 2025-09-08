// lib/services/user_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
// import 'package:firebase_storage/firebase_storage.dart';  // Temporarily disabled
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/image_optimization_service.dart';
// import 'package:geolocator/geolocator.dart';  // Temporarily disabled
import 'package:firebase_messaging/firebase_messaging.dart';

enum SwipeAction { reject, friend, crush }

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseStorage _storage = FirebaseStorage.instance;  // Temporarily disabled
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<void> createUser(User user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<User?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return User.fromFirestore(doc);
    }
    return null;
  }

  Stream<User?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return User.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Future<void> updateUser(User user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  /// Partially update user document with arbitrary fields
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<String?> uploadProfilePhoto(String uid, File imageFile) async {
    try {
      // Use the optimized profile picture upload service
      return await ImageOptimizationService.uploadOptimizedProfilePicture(
        uid,
        imageFile,
        onProgress: (progress) {
          print(
              'Profile photo upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );
    } catch (e) {
      print('Error uploading profile photo: $e');
      // Fallback to original method if optimization fails
      String fileName =
          'profile_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      // UploadTask uploadTask = _storage.ref().child(fileName).putFile(imageFile);  // Temporarily disabled
      // TaskSnapshot snapshot = await uploadTask;  // Temporarily disabled
      // return await snapshot.ref.getDownloadURL();  // Temporarily disabled
      return null; // Temporarily return null
    }
  }

  Future<String?> swipeUser(String swipedUserId, SwipeAction action) async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) throw Exception('User not logged in.');

    DocumentReference currentUserRef =
        _firestore.collection('users').doc(currentUserId);
    DocumentReference swipedUserRef =
        _firestore.collection('users').doc(swipedUserId);

    String fieldToAdd;
    switch (action) {
      case SwipeAction.reject:
        fieldToAdd = 'rejectedUsers';
        break;
      case SwipeAction.friend:
        fieldToAdd = 'friendedUsers';
        break;
      case SwipeAction.crush:
        fieldToAdd = 'crushedUsers';
        break;
    }

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot swipedUserDoc = await transaction.get(swipedUserRef);
      if (!swipedUserDoc.exists) throw Exception('Swiped user does not exist.');

      User swipedUser = User.fromFirestore(swipedUserDoc);

      // For reject action, just add to rejected list
      if (action == SwipeAction.reject) {
        transaction.update(currentUserRef, {
          fieldToAdd: FieldValue.arrayUnion([swipedUserId])
        });
        return null;
      }

      // For friend/crush actions, check if there's a mutual swipe
      transaction.update(currentUserRef, {
        fieldToAdd: FieldValue.arrayUnion([swipedUserId])
      });

      if (action == SwipeAction.friend) {
        if (swipedUser.friendedUsers.contains(currentUserId)) {
          // Mutual friend swipe - create match
          transaction.update(currentUserRef, {
            'friendMatches': FieldValue.arrayUnion([swipedUserId])
          });
          transaction.update(swipedUserRef, {
            'friendMatches': FieldValue.arrayUnion([currentUserId])
          });
          return 'friend_match';
        } else {
          // Send friend request notification
          await _sendSwipeRequest(currentUserId, swipedUserId, 'friend');
          return 'friend_request_sent';
        }
      } else if (action == SwipeAction.crush) {
        if (swipedUser.crushedUsers.contains(currentUserId) ||
            swipedUser.friendedUsers.contains(currentUserId)) {
          // Mutual crush or friend+crush - create crush match
          transaction.update(currentUserRef, {
            'crushMatches': FieldValue.arrayUnion([swipedUserId])
          });
          transaction.update(swipedUserRef, {
            'crushMatches': FieldValue.arrayUnion([currentUserId])
          });

          // Remove from friend matches if they were friends
          transaction.update(currentUserRef, {
            'friendMatches': FieldValue.arrayRemove([swipedUserId])
          });
          transaction.update(swipedUserRef, {
            'friendMatches': FieldValue.arrayRemove([currentUserId])
          });
          return 'crush_match';
        } else {
          // Send crush request notification
          await _sendSwipeRequest(currentUserId, swipedUserId, 'crush');
          return 'crush_request_sent';
        }
      }

      return null;
    });
  }

  /// Send a swipe request notification
  Future<void> _sendSwipeRequest(
      String senderId, String receiverId, String type) async {
    try {
      // Create request in Firestore
      await _firestore.collection('requests').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'type': type, // 'friend' or 'crush'
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send push notification
      await _sendSwipeNotification(senderId, receiverId, type);
    } catch (e) {
      print('Error sending swipe request: $e');
    }
  }

  /// Send push notification for swipe request
  Future<void> _sendSwipeNotification(
      String senderId, String receiverId, String type) async {
    try {
      // Get sender's info
      final senderUser = await getUser(senderId);
      if (senderUser == null) return;

      // Get receiver's FCM token
      final receiverUser = await getUser(receiverId);
      if (receiverUser?.fcmToken == null) return;

      // Prepare notification payload
      final title =
          type == 'crush' ? '💜 New Crush!' : '👥 New Friend Request!';
      final body =
          '${senderUser.displayName ?? 'Someone'} ${type == 'crush' ? 'has a crush on you' : 'wants to be friends'}!';

      // Send notification via Firebase Functions or your notification service
      // This would typically call your backend API or Firebase Functions
      await _firestore.collection('notifications').add({
        'token': receiverUser?.fcmToken ?? '',
        'title': title,
        'body': body,
        'data': {
          'type': 'swipe_request',
          'senderId': senderId,
          'requestType': type,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });
    } catch (e) {
      print('Error sending swipe notification: $e');
    }
  }

  Future<List<User>> getPotentialMatches({
    int? limit,
    User? lastDocument,
  }) async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return [];

    User? currentUser = await getUser(currentUserId);
    if (currentUser == null) return [];

    List<String> excludedIds = [
      currentUserId,
      ...currentUser.rejectedUsers,
      ...currentUser.friendedUsers,
      ...currentUser.crushedUsers,
      ...currentUser.friendMatches,
      ...currentUser.crushMatches,
    ];

    Query query = _firestore.collection('users');

    // Apply gender preference filter
    if (currentUser.genderPreference != null &&
        currentUser.genderPreference != 'Both') {
      query = query.where('gender', isEqualTo: currentUser.genderPreference);
    }

    // Apply pagination
    if (lastDocument != null) {
      query = query.startAfter([lastDocument.uid]);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final QuerySnapshot snapshot = await query.get();

    final potentialMatches = snapshot.docs
        .map((doc) => User.fromFirestore(doc))
        .where((user) => !excludedIds.contains(user.uid))
        .toList();

    return potentialMatches;
  }

  Future<Map<User, String>> getPendingMatches() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return {};

    User? currentUser = await getUser(currentUserId);
    if (currentUser == null) return {};

    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .where(Filter.or(Filter('friendedUsers', arrayContains: currentUserId),
            Filter('crushedUsers', arrayContains: currentUserId)))
        .get();

    Map<User, String> pendingMatches = {};
    for (var doc in querySnapshot.docs) {
      User user = User.fromFirestore(doc);

      String requestType =
          user.crushedUsers.contains(currentUserId) ? 'crush' : 'friend';

      bool alreadySwiped = currentUser.rejectedUsers.contains(user.uid) ||
          currentUser.friendedUsers.contains(user.uid) ||
          currentUser.crushedUsers.contains(user.uid);

      if (!alreadySwiped) {
        pendingMatches[user] = requestType;
      }
    }
    return pendingMatches;
  }

  Future<List<User>> getFriendMatches() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return [];
    User? currentUser = await getUser(currentUserId);
    if (currentUser == null || currentUser.friendMatches.isEmpty) return [];

    final users = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: currentUser.friendMatches)
        .get();
    return users.docs.map((doc) => User.fromFirestore(doc)).toList();
  }

  Future<List<User>> getCrushMatches() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return [];
    User? currentUser = await getUser(currentUserId);
    if (currentUser == null || currentUser.crushMatches.isEmpty) return [];

    final users = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: currentUser.crushMatches)
        .get();
    return users.docs.map((doc) => User.fromFirestore(doc)).toList();
  }

  Future<List<User>> getReportedUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('reportedByUsers', isNotEqualTo: []).get();

      return querySnapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting reported users: $e');
      rethrow;
    }
  }

  /// Update user media URLs in Firestore
  Future<void> updateUserMedia(String uid, List<String> mediaUrls) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'mediaUrls': mediaUrls});
  }
}
