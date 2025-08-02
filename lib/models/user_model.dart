// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // Import if Location is used


class User {
  final String uid;
  final String email;
  final String? displayName;
  final String? bio;
  final List<String> profilePhotos;
  final String? gender;
  final String? college;
  final int? age;
  final GeoPoint? location; // Firestore stores GeoPoint, not Position
  final String? fcmToken;
  final Timestamp? boostEndTime;
  final List<String> likedUsers;
  final List<String> dislikedUsers;
  final List<String> matches;
  final List<String> blockedUsers;
  final List<String> reportedByUsers;
  final List<String> interests;
  final String? education;
  final Map<String, dynamic> prompts;
  final String? genderPreference; // New field for "Looking for" preference
  final int? minAgePreference;
  final int? maxAgePreference;
  final double? maxDistancePreference;
  final bool isOnline;
  final Timestamp? lastActive;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.bio,
    this.profilePhotos = const [],
    this.gender,
    this.college,
    this.age,
    this.location,
    this.fcmToken,
    this.boostEndTime,
    this.likedUsers = const [],
    this.dislikedUsers = const [],
    this.matches = const [],
    this.blockedUsers = const [],
    this.reportedByUsers = const [],
    this.interests = const [],
    this.education,
    this.prompts = const {},
    this.genderPreference = 'Both', // Default to 'Both'
    this.minAgePreference,
    this.maxAgePreference,
    this.maxDistancePreference,
    this.isOnline = false,
    this.lastActive,
  });

  // Factory constructor to create a User from a Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return User(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      bio: data['bio'] ?? '',
      profilePhotos: List<String>.from(data['profilePhotos'] ?? []),
      gender: data['gender'] ?? '',
      college: data['college'] ?? '',
      age: data['age'] as int?,
      location: data['location'] as GeoPoint?,
      fcmToken: data['fcmToken'] as String?,
      boostEndTime: data['boostEndTime'] as Timestamp?,
      likedUsers: List<String>.from(data['likedUsers'] ?? []),
      dislikedUsers: List<String>.from(data['dislikedUsers'] ?? []),
      matches: List<String>.from(data['matches'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      reportedByUsers: List<String>.from(data['reportedByUsers'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      education: data['education'] ?? '',
      prompts: Map<String, dynamic>.from(data['prompts'] ?? {}),
      genderPreference: data['genderPreference'] ?? 'Both', // Deserialize new field
      minAgePreference: data['minAgePreference'] as int?,
      maxAgePreference: data['maxAgePreference'] as int?,
      maxDistancePreference: data['maxDistancePreference'] as double?,
      isOnline: data['isOnline'] ?? false,
      lastActive: data['lastActive'] as Timestamp?,
    );
  }

  // Convert a User object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'profilePhotos': profilePhotos,
      'gender': gender,
      'college': college,
      'age': age,
      'location': location,
      'fcmToken': fcmToken,
      'boostEndTime': boostEndTime,
      'likedUsers': likedUsers,
      'dislikedUsers': dislikedUsers,
      'matches': matches,
      'blockedUsers': blockedUsers,
      'reportedByUsers': reportedByUsers,
      'interests': interests,
      'education': education,
      'prompts': prompts,
      'genderPreference': genderPreference, // Serialize new field
      'minAgePreference': minAgePreference,
      'maxAgePreference': maxAgePreference,
      'maxDistancePreference': maxDistancePreference,
      'isOnline': isOnline,
      'lastActive': lastActive,
    };
  }

  // Method to create a copy of User with updated fields
  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? bio,
    List<String>? profilePhotos,
    String? gender,
    String? college,
    int? age,
    GeoPoint? location,
    String? fcmToken,
    Timestamp? boostEndTime,
    List<String>? likedUsers,
    List<String>? dislikedUsers,
    List<String>? matches,
    List<String>? blockedUsers,
    List<String>? reportedByUsers,
    List<String>? interests,
    String? education,
    Map<String, dynamic>? prompts,
    String? genderPreference, // CopyWith new field
    int? minAgePreference,
    int? maxAgePreference,
    double? maxDistancePreference,
    bool? isOnline,
    Timestamp? lastActive,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profilePhotos: profilePhotos ?? this.profilePhotos,
      gender: gender ?? this.gender,
      college: college ?? this.college,
      age: age ?? this.age,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      boostEndTime: boostEndTime ?? this.boostEndTime,
      likedUsers: likedUsers ?? this.likedUsers,
      dislikedUsers: dislikedUsers ?? this.dislikedUsers,
      matches: matches ?? this.matches,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      reportedByUsers: reportedByUsers ?? this.reportedByUsers,
      interests: interests ?? this.interests,
      education: education ?? this.education,
      prompts: prompts ?? this.prompts,
      genderPreference: genderPreference ?? this.genderPreference, // Assign new field
      minAgePreference: minAgePreference ?? this.minAgePreference,
      maxAgePreference: maxAgePreference ?? this.maxAgePreference,
      maxDistancePreference: maxDistancePreference ?? this.maxDistancePreference,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}