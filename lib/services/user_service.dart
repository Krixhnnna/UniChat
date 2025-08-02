// lib/services/user_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:geolocator/geolocator.dart'; // For location services
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging


class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance; // Instance for FCM

  // Get current user's UID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Create a new user in Firestore
  Future<void> createUser(User user) async {
    try {
      // Get FCM token and add to user data before creating
      String? fcmToken = await _firebaseMessaging.getToken();
      User userWithToken = user.copyWith(fcmToken: fcmToken);

      await _firestore.collection('users').doc(user.uid).set(userWithToken.toMap());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Get user data by UID
  Future<User?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      rethrow;
    }
  }

  // New method: Get a real-time stream of user data by UID
  Stream<User?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return User.fromFirestore(snapshot);
      }
      return null;
    });
  }

  // Update user data in Firestore
  Future<void> updateUser(User user) async {
    try {
      // Ensure the UID is not null before attempting to update
      if (user.uid == null) {
        throw Exception('User UID cannot be null for update operation.');
      }
      // SetOptions(merge: true) is used to update fields without overwriting the entire document.
      // This is crucial for updating things like profile photos without affecting other fields.
      await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Upload profile photo to Firebase Storage
  Future<String?> uploadProfilePhoto(String uid, File imageFile) async {
    try {
      String fileName = 'profile_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      UploadTask uploadTask = _storage.ref().child(fileName).putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      rethrow;
    }
  }

  // Method to update the user's FCM token in Firestore
  Future<void> updateFcmToken(String uid) async {
    try {
      String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': fcmToken,
        });
        print('FCM token updated for user $uid: $fcmToken');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Swipe logic (like/dislike)
  Future<void> swipeUser(String swipedUserId, bool liked) async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception('User not logged in.');
    }

    DocumentReference currentUserRef = _firestore.collection('users').doc(currentUserId);
    DocumentReference swipedUserRef = _firestore.collection('users').doc(swipedUserId);

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot currentUserDoc = await transaction.get(currentUserRef);
      DocumentSnapshot swipedUserDoc = await transaction.get(swipedUserRef);

      if (!currentUserDoc.exists || !swipedUserDoc.exists) {
        throw Exception('User data not found for swipe operation.');
      }

      User currentUser = User.fromFirestore(currentUserDoc);
      User swipedUser = User.fromFirestore(swipedUserDoc);

      if (liked) {
        if (!currentUser.likedUsers.contains(swipedUserId)) {
          currentUser.likedUsers.add(swipedUserId);
        }
        if (swipedUser.likedUsers.contains(currentUserId)) {
          if (!currentUser.matches.contains(swipedUserId)) {
            currentUser.matches.add(swipedUserId);
          }
          if (!swipedUser.matches.contains(currentUserId)) {
            swipedUser.matches.add(currentUserId);
          }
          print('MATCH! ${currentUser.displayName} and ${swipedUser.displayName}');
          // TODO: Trigger a push notification for the match!
        }
      } else {
        if (!currentUser.dislikedUsers.contains(swipedUserId)) {
          currentUser.dislikedUsers.add(swipedUserId);
        }
      }

      transaction.update(currentUserRef, {
        'likedUsers': currentUser.likedUsers,
        'dislikedUsers': currentUser.dislikedUsers,
        'matches': currentUser.matches,
      });
      transaction.update(swipedUserRef, {
        'matches': swipedUser.matches,
      });
    });
  }

  Future<bool> checkMatch(String swipedUserId) async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    DocumentSnapshot swipedUserDoc = await _firestore.collection('users').doc(swipedUserId).get();

    if (!currentUserDoc.exists || !swipedUserDoc.exists) {
      return false;
    }

    User currentUser = User.fromFirestore(currentUserDoc);
    User swipedUser = User.fromFirestore(swipedUserDoc);

    return currentUser.matches.contains(swipedUserId) && swipedUser.matches.contains(currentUserId);
  }

  // Get potential matches based on preferences and already swiped users
  Future<List<User>> getPotentialMatches() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      return [];
    }

    User? currentUser = await getUser(currentUserId);
    if (currentUser == null) {
      return [];
    }

    List<String> alreadySwiped = [...currentUser.likedUsers, ...currentUser.dislikedUsers];
    alreadySwiped.add(currentUserId); // Don't show current user

    Query query = _firestore.collection('users');

    // Apply gender preference
    if (currentUser.genderPreference != null && currentUser.genderPreference != 'Both') {
      query = query.where('gender', isEqualTo: currentUser.genderPreference);
    }

    // Apply age preference
    if (currentUser.minAgePreference != null) {
      query = query.where('age', isGreaterThanOrEqualTo: currentUser.minAgePreference);
    }
    if (currentUser.maxAgePreference != null) {
      query = query.where('age', isLessThanOrEqualTo: currentUser.maxAgePreference);
    }

    QuerySnapshot snapshot = await query.get();
    List<User> allUsers = snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();

    List<User> potentialMatches = [];
    for (User user in allUsers) {
      if (alreadySwiped.contains(user.uid)) {
        continue;
      }
      potentialMatches.add(user);
    }
    return potentialMatches;
  }
  
  // New method to get pending matches (users who liked you) [cite: lib/services/user_service.dart]
  Future<List<User>> getPendingMatches() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return [];

    // Find all users who have liked the current user but are not yet matched
    QuerySnapshot querySnapshot = await _firestore.collection('users')
        .where('likedUsers', arrayContains: currentUserId)
        .get();

    List<User> likedByUsers = querySnapshot.docs.map((doc) => User.fromFirestore(doc)).toList();

    // Now, filter out users that the current user has already liked or disliked
    User? currentUser = await getUser(currentUserId);
    if (currentUser == null) return [];
    
    // Remove users the current user has already swiped on
    List<User> pendingMatches = likedByUsers.where((user) {
      return !currentUser.likedUsers.contains(user.uid!) && !currentUser.dislikedUsers.contains(user.uid!);
    }).toList();

    return pendingMatches;
  }


  Future<List<User>> getMatches() async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      return [];
    }

    User? currentUser = await getUser(currentUserId);
    if (currentUser == null || currentUser.matches.isEmpty) {
      return [];
    }

    List<User> matchedUsers = [];
    for (String uid in currentUser.matches) {
      User? user = await getUser(uid);
      if (user != null) {
        matchedUsers.add(user);
      }
    }
    return matchedUsers;
  }

  Future<void> blockUser(String userIdToBlock) async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception('User not logged in.');
    }

    await _firestore.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayUnion([userIdToBlock]),
    });
    print('User $userIdToBlock blocked by $currentUserId');
  }

  Future<void> reportUser(String userIdToReport, String reason) async {
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception('User not logged in.');
    }

    await _firestore.collection('users').doc(userIdToReport).update({
      'reportedByUsers': FieldValue.arrayUnion([currentUserId]),
    });

    await _firestore.collection('reports').add({
      'reporterId': currentUserId,
      'reportedId': userIdToReport,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
    print('User $userIdToReport reported by $currentUserId for reason: $reason');
  }
}