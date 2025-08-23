// lib/services/user_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/image_optimization_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum SwipeAction { reject, friend, crush }

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
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
      UploadTask uploadTask = _storage.ref().child(fileName).putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
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

      transaction.update(currentUserRef, {
        fieldToAdd: FieldValue.arrayUnion([swipedUserId])
      });

      if (action == SwipeAction.friend) {
        if (swipedUser.friendedUsers.contains(currentUserId)) {
          transaction.update(currentUserRef, {
            'friendMatches': FieldValue.arrayUnion([swipedUserId])
          });
          transaction.update(swipedUserRef, {
            'friendMatches': FieldValue.arrayUnion([currentUserId])
          });
          return 'friend_match';
        }
      } else if (action == SwipeAction.crush) {
        if (swipedUser.crushedUsers.contains(currentUserId) ||
            swipedUser.friendedUsers.contains(currentUserId)) {
          transaction.update(currentUserRef, {
            'crushMatches': FieldValue.arrayUnion([swipedUserId])
          });
          transaction.update(swipedUserRef, {
            'crushMatches': FieldValue.arrayUnion([currentUserId])
          });

          transaction.update(currentUserRef, {
            'friendMatches': FieldValue.arrayRemove([swipedUserId])
          });
          transaction.update(swipedUserRef, {
            'friendMatches': FieldValue.arrayRemove([currentUserId])
          });
          return 'crush_match';
        }
      }

      return null;
    });
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
