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
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
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

  Future<UserCredential?> signIn(String email, String password) async {
    // ... (this method remains the same)
  }

  Future<void> signOut() async {
    // ... (this method remains the same)
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}