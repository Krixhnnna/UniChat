// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  AuthService() {
    WidgetsBinding.instance.addObserver(this);
    // ... (lifecycle logic remains the same)
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ... (lifecycle logic remains the same)
  }

  Future<void> _updateUserStatus(String uid, bool isOnline) async {
    // ... (this method remains the same)
  }

  // --- CORRECTED SIGNUP METHOD ---
  Future<String?> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // This now creates a user document with the NEW data structure
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': '',
        'bio': '',
        'profilePhotos': [],
        'gender': '',
        'college': '',
        'age': null,
        'location': null,
        'fcmToken': null,
        'boostEndTime': null,
        // --- NEW FIELDS ---
        'rejectedUsers': [],
        'friendedUsers': [],
        'crushedUsers': [],
        'friendMatches': [],
        'crushMatches': [],
        // --- END NEW FIELDS ---
        'blockedUsers': [],
        'reportedByUsers': [],
        'interests': [],
        'education': '',
        'prompts': {},
        'genderPreference': 'Both',
        'minAgePreference': 18,
        'maxAgePreference': 30,
        'maxDistancePreference': 50.0,
        'isOnline': true,
        'lastActive': FieldValue.serverTimestamp(),
        'role': 'user',
      });

      await userCredential.user!.sendEmailVerification();
      return userCredential.user?.uid;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during signup: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error during signup: $e');
      rethrow;
    }
  }

  // New signUp method for the updated flow - NO Firestore save until email verification
  Future<String?> signUp(String email, String password, String username,
      String name, DateTime dob) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email immediately
      await userCredential.user!.sendEmailVerification();

      // DO NOT save to Firestore yet - wait for email verification
      // User data will be saved only after email is verified

      return userCredential.user?.uid;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during signup: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error during signup: $e');
      rethrow;
    }
  }

  // New method to complete user profile after email verification
  Future<void> completeUserProfileAfterVerification(String uid, String email,
      String username, String name, DateTime dob) async {
    try {
      // Calculate age from DOB
      final age = DateTime.now().difference(dob).inDays ~/ 365;

      // Create user document ONLY after email verification
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'username': username,
        'displayName': name,
        'name': name,
        'dateOfBirth': Timestamp.fromDate(dob),
        'age': age,
        'bio': '',
        'profilePhotos': [],
        'gender': '',
        'college': '',
        'location': null,
        'fcmToken': null,
        'boostEndTime': null,
        'rejectedUsers': [],
        'friendedUsers': [],
        'crushedUsers': [],
        'friendMatches': [],
        'crushMatches': [],
        'blockedUsers': [],
        'reportedByUsers': [],
        'interests': [],
        'education': '',
        'prompts': {},
        'genderPreference': 'Both',
        'minAgePreference': 18,
        'maxAgePreference': 30,
        'maxDistancePreference': 50.0,
        'isOnline': true,
        'lastActive': FieldValue.serverTimestamp(),
        'role': 'user',
      });

      print(
          'User profile completed and saved to Firestore after email verification');
    } catch (e) {
      print('Error completing user profile: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user status to online after successful sign in
      if (userCredential.user != null) {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error during sign in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Update user status to offline before signing out
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'isOnline': false,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      // Sign out from Firebase Auth
      await _auth.signOut();

      // Clear any cached data or preferences here if needed
      // You can add SharedPreferences.clear() if you're using SharedPreferences
    } catch (e) {
      print('Error during sign out: $e');
      // Even if there's an error, force sign out
      await _auth.signOut();
    }
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}
