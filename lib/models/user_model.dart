import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  String name;
  String? bio; // User's biography
  String? gender; // e.g., 'Male', 'Female', 'Non-binary'
  String? interestedIn; // e.g., 'Male', 'Female', 'Everyone' (for matching preferences)
  int? age;
  String? location; // City, region, or general area
  List<String>? photoUrls; // List of URLs for profile pictures
  String? fcmToken; // Firebase Cloud Messaging device token for push notifications
  List<String>? blockedUsers; // List of UIDs of users blocked by this user
  bool? isOnline; // User's online status
  Timestamp? lastActive; // Timestamp of last activity
  Timestamp? boostEndTime; // New: Timestamp when profile boost expires

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.bio,
    this.gender,
    this.interestedIn,
    this.age,
    this.location,
    this.photoUrls,
    this.fcmToken,
    this.blockedUsers,
    this.isOnline,
    this.lastActive,
    this.boostEndTime, // Add this
  });

  // Factory constructor to create a UserModel from a Firestore DocumentSnapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return UserModel(
      uid: snap.id,
      email: snapshot['email'] ?? '',
      name: snapshot['name'] ?? '',
      bio: snapshot['bio'],
      gender: snapshot['gender'],
      interestedIn: snapshot['interestedIn'],
      age: snapshot['age'],
      location: snapshot['location'],
      photoUrls: List<String>.from(snapshot['photoUrls'] ?? []),
      fcmToken: snapshot['fcmToken'],
      blockedUsers: List<String>.from(snapshot['blockedUsers'] ?? []),
      isOnline: snapshot['isOnline'],
      lastActive: snapshot['lastActive'] as Timestamp?,
      boostEndTime: snapshot['boostEndTime'] as Timestamp?, // Map boostEndTime
    );
  }

  // Method to convert a UserModel instance into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'bio': bio,
      'gender': gender,
      'interestedIn': interestedIn,
      'age': age,
      'location': location,
      'photoUrls': photoUrls,
      'lastActive': FieldValue.serverTimestamp(),
      'fcmToken': fcmToken,
      'blockedUsers': blockedUsers,
      'isOnline': isOnline,
      'boostEndTime': boostEndTime, // Include boostEndTime
    };
  }

  // Helper getter to check if the boost is active
  bool get isBoosted {
    if (boostEndTime == null) return false;
    return boostEndTime!.toDate().isAfter(DateTime.now());
  }
}
