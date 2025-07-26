import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io'; // For File on mobile
import 'package:image_picker/image_picker.dart'; // Import XFile
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection reference for users (made public)
  CollectionReference get usersCollection => _firestore.collection('users');
  // Collection reference for matches
  CollectionReference get _matchesCollection => _firestore.collection('matches');
  // Collection for user reports
  CollectionReference get _reportsCollection => _firestore.collection('reports');

  // Create or update a user profile in Firestore
  Future<void> createUserProfile(UserModel user) async {
    try {
      // Debug print: Show the data received by UserService
      print('UserService: Received user data for saving: ${user.toMap()}');

      await usersCollection.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
      print('UserService: Profile for ${user.uid} saved successfully.');
    } catch (e) {
      print('Error creating/updating user profile: $e');
      rethrow;
    }
  }

  // Get a user profile by UID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await usersCollection.doc(uid).get();
      if (doc.exists) {
        final userModel = UserModel.fromSnapshot(doc);
        print('UserService: Fetched user profile for ${uid}: ${userModel.toMap()}');
        return userModel;
      }
      print('UserService: User profile for ${uid} not found.');
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  // Upload a profile photo to Firebase Storage and return its URL
  // Now accepts XFile to handle both web and mobile
  Future<String> uploadProfilePhoto(String uid, XFile imageFile, String fileName) async {
    try {
      Reference storageRef = _storage.ref().child('profile_photos/$uid/$fileName');
      UploadTask uploadTask;

      // Check if running on web or mobile
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = storageRef.putData(bytes);
      } else {
        // For mobile/desktop platforms, use putFile
        uploadTask = storageRef.putFile(File(imageFile.path));
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('UserService: Photo uploaded to: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      rethrow;
    }
  }

  // Add a photo URL to a user's profile
  Future<void> addPhotoUrlToProfile(String uid, String photoUrl) async {
    try {
      await usersCollection.doc(uid).update({
        'photoUrls': FieldValue.arrayUnion([photoUrl]),
      });
      print('UserService: Added photo URL $photoUrl to user $uid profile.');
    } catch (e) {
      print('Error adding photo URL to profile: $e');
      rethrow;
    }
  }

  // Remove a photo URL from a user's profile
  Future<void> removePhotoUrlFromProfile(String uid, String photoUrl) async {
    try {
      await usersCollection.doc(uid).update({
        'photoUrls': FieldValue.arrayRemove([photoUrl]),
      });
      print('UserService: Removed photo URL $photoUrl from user $uid profile.');
    } catch (e) {
      print('Error removing photo URL from profile: $e');
      rethrow;
    }
  }

  // Method to block a user
  Future<void> blockUser(String currentUserId, String userToBlockId) async {
    try {
      await usersCollection.doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([userToBlockId]),
      });
      print('User $userToBlockId blocked by $currentUserId');
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  // Method to report a user
  Future<void> reportUser(String reporterId, String reportedId, String reason) async {
    try {
      await _reportsCollection.add({
        'reporterId': reporterId,
        'reportedId': reportedId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      print('User $reportedId reported by $reporterId for reason: $reason');
    } catch (e) {
      print('Error reporting user: $e');
      rethrow;
    }
  }

  // Method to update a user's FCM device token
  Future<void> updateFcmToken(String uid, String? token) async {
    try {
      await usersCollection.doc(uid).update({
        'fcmToken': token,
      });
      print('FCM token updated for user $uid: $token');
    } catch (e) {
      print('Error updating FCM token: $e');
      rethrow;
    }
  }

  // New: Method to boost a user's profile for a given duration
  Future<void> boostProfile(String uid, Duration duration) async {
    try {
      final newBoostEndTime = Timestamp.fromDate(DateTime.now().add(duration));
      await usersCollection.doc(uid).update({
        'boostEndTime': newBoostEndTime,
      });
      print('User $uid profile boosted until ${newBoostEndTime.toDate()}');
    } catch (e) {
      print('Error boosting profile: $e');
      rethrow;
    }
  }

  // Fetch potential matches for the current user with filters, blocking, and boost prioritization
  Stream<List<UserModel>> getPotentialMatches(
    String currentUserId, {
    String? genderPreference,
    int? minAge,
    int? maxAge,
    String? locationFilter,
  }) {
    final blockedByMeStream = usersCollection
        .doc(currentUserId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() as Map<String, dynamic>?;
          return List<String>.from(data?['blockedUsers'] ?? []);
        });

    final blockedMeStream = usersCollection
        .where('blockedUsers', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());

    return Rx.combineLatest2(blockedByMeStream, blockedMeStream, (blockedByMe, blockedMe) {
      Set<String> excludedUserIds = {};
      excludedUserIds.addAll(blockedByMe);
      excludedUserIds.addAll(blockedMe);
      excludedUserIds.add(currentUserId);

      Query query = usersCollection;

      if (genderPreference != null && genderPreference != 'Everyone') {
        query = query.where('gender', isEqualTo: genderPreference);
      }
      if (minAge != null) {
        query = query.where('age', isGreaterThanOrEqualTo: minAge);
      }
      if (maxAge != null) {
        query = query.where('age', isLessThanOrEqualTo: maxAge);
      }
      if (locationFilter != null && locationFilter.isNotEmpty) {
        query = query.where('location', isEqualTo: locationFilter);
      }

      return query.snapshots().map((snapshot) {
        List<UserModel> allPotentialUsers = snapshot.docs
            .map((doc) => UserModel.fromSnapshot(doc))
            .where((user) => !excludedUserIds.contains(user.uid))
            .toList();

        List<UserModel> boostedUsers = [];
        List<UserModel> normalUsers = [];

        for (var user in allPotentialUsers) {
          if (user.isBoosted) {
            boostedUsers.add(user);
          } else {
            normalUsers.add(user);
          }
        }

        return [...boostedUsers, ...normalUsers];
      });
    }).switchMap((streamOfList) => streamOfList);
  }

  Future<void> recordSwipe(String swiperId, String swipedId, String action) async {
    try {
      await _firestore.collection('swipes').doc(swiperId).collection('actions').doc(swipedId).set({
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (action == 'liked') {
        DocumentSnapshot swipedBack = await _firestore.collection('swipes').doc(swipedId).collection('actions').doc(swiperId).get();

        if (swipedBack.exists && swipedBack['action'] == 'liked') {
          await _createMatch(swiperId, swipedId);
        }
      }
    } catch (e) {
      print('Error recording swipe: $e');
      rethrow;
    }
  }

  Future<void> _createMatch(String user1Id, String user2Id) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String matchId = userIds.join('_');

    try {
      await _matchesCollection.doc(matchId).set({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'matched',
      });
      print('Match created between $user1Id and $user2Id');

      UserModel? user1 = await getUserProfile(user1Id);
      UserModel? user2 = await getUserProfile(user2Id);

      if (user1 != null && user2 != null) {
        if (user1.fcmToken != null) {
          print('Would send match notification to ${user1.name} (${user1.fcmToken}) about ${user2.name}');
        }
        if (user2.fcmToken != null) {
          print('Would send match notification to ${user2.name} (${user2.fcmToken}) about ${user1.name}');
        }
      }

    } catch (e) {
      print('Error creating match: $e');
      rethrow;
    }
  }

  Stream<List<UserModel>> getMatches(String currentUserId) {
    Stream<List<UserModel>> matchesAsUser1 = _matchesCollection
        .where('user1Id', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          List<UserModel> users = [];
          for (var doc in snapshot.docs) {
            String matchedUserId = doc['user2Id'];
            UserModel? matchedUser = await getUserProfile(matchedUserId);
            if (matchedUser != null) {
              users.add(matchedUser);
            }
          }
          return users;
        });

    Stream<List<UserModel>> matchesAsUser2 = _matchesCollection
        .where('user2Id', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          List<UserModel> users = [];
          for (var doc in snapshot.docs) {
            String matchedUserId = doc['user1Id'];
            UserModel? matchedUser = await getUserProfile(matchedUserId);
            if (matchedUser != null) {
              users.add(matchedUser);
            }
          }
          return users;
        });

    return Rx.combineLatest2(matchesAsUser1, matchesAsUser2, (list1, list2) {
      Set<UserModel> combined = {};
      combined.addAll(list1);
      combined.addAll(list2);
      return combined.toList();
    });
  }

  Future<DocumentSnapshot?> getMatchDocument(String user1Id, String user2Id) async {
    List<String> userIds = [user1Id, user2Id]..sort();
    String matchId = userIds.join('_');
    return await _matchesCollection.doc(matchId).get();
  }
}
