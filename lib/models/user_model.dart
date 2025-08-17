// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class User {
  final String uid;
  final String email;
  final String? displayName;
  final String? bio;
  final List<String> profilePhotos;
  final String? gender;
  final String? college;
  final int? age;
  final GeoPoint? location;
  final String? fcmToken;
  final Timestamp? boostEndTime;
  final List<String> rejectedUsers;
  final List<String> friendedUsers;
  final List<String> crushedUsers;
  final List<String> friendMatches;
  final List<String> crushMatches;
  final List<String> blockedUsers;
  final List<String> reportedByUsers;
  final List<String> interests;
  final String? education;
  final Map<String, dynamic> prompts;
  final String? genderPreference;
  final int? minAgePreference;
  final int? maxAgePreference;
  final double? maxDistancePreference;
  final bool isOnline;
  final Timestamp? lastActive;
  final String role;

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
    this.rejectedUsers = const [],
    this.friendedUsers = const [],
    this.crushedUsers = const [],
    this.friendMatches = const [],
    this.crushMatches = const [],
    this.blockedUsers = const [],
    this.reportedByUsers = const [],
    this.interests = const [],
    this.education,
    this.prompts = const {},
    this.genderPreference = 'Both',
    this.minAgePreference,
    this.maxAgePreference,
    this.maxDistancePreference,
    this.isOnline = false,
    this.lastActive,
    this.role = 'user',
  });

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
      rejectedUsers: List<String>.from(data['rejectedUsers'] ?? []),
      friendedUsers: List<String>.from(data['friendedUsers'] ?? []),
      crushedUsers: List<String>.from(data['crushedUsers'] ?? []),
      friendMatches: List<String>.from(data['friendMatches'] ?? []),
      crushMatches: List<String>.from(data['crushMatches'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      reportedByUsers: List<String>.from(data['reportedByUsers'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      education: data['education'] ?? '',
      prompts: Map<String, dynamic>.from(data['prompts'] ?? {}),
      genderPreference: data['genderPreference'] ?? 'Both',
      minAgePreference: data['minAgePreference'] as int?,
      maxAgePreference: data['maxAgePreference'] as int?,
      maxDistancePreference: data['maxDistancePreference'] as double?,
      isOnline: data['isOnline'] ?? false,
      lastActive: data['lastActive'] as Timestamp?,
      role: data['role'] ?? 'user',
    );
  }

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
      'rejectedUsers': rejectedUsers,
      'friendedUsers': friendedUsers,
      'crushedUsers': crushedUsers,
      'friendMatches': friendMatches,
      'crushMatches': crushMatches,
      'blockedUsers': blockedUsers,
      'reportedByUsers': reportedByUsers,
      'interests': interests,
      'education': education,
      'prompts': prompts,
      'genderPreference': genderPreference,
      'minAgePreference': minAgePreference,
      'maxAgePreference': maxAgePreference,
      'maxDistancePreference': maxDistancePreference,
      'isOnline': isOnline,
      'lastActive': lastActive,
      'role': role,
    };
  }

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
    List<String>? rejectedUsers,
    List<String>? friendedUsers,
    List<String>? crushedUsers,
    List<String>? friendMatches,
    List<String>? crushMatches,
    List<String>? blockedUsers,
    List<String>? reportedByUsers,
    List<String>? interests,
    String? education,
    Map<String, dynamic>? prompts,
    String? genderPreference,
    int? minAgePreference,
    int? maxAgePreference,
    double? maxDistancePreference,
    bool? isOnline,
    Timestamp? lastActive,
    String? role,
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
      rejectedUsers: rejectedUsers ?? this.rejectedUsers,
      friendedUsers: friendedUsers ?? this.friendedUsers,
      crushedUsers: crushedUsers ?? this.crushedUsers,
      friendMatches: friendMatches ?? this.friendMatches,
      crushMatches: crushMatches ?? this.crushMatches,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      reportedByUsers: reportedByUsers ?? this.reportedByUsers,
      interests: interests ?? this.interests,
      education: education ?? this.education,
      prompts: prompts ?? this.prompts,
      genderPreference: genderPreference ?? this.genderPreference,
      minAgePreference: minAgePreference ?? this.minAgePreference,
      maxAgePreference: maxAgePreference ?? this.maxAgePreference,
      maxDistancePreference: maxDistancePreference ?? this.maxDistancePreference,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
      role: role ?? this.role,
    );
  }
}