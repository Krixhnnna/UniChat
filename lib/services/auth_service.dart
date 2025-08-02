// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For WidgetsBindingObserver

class AuthService with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of Firebase User changes
  Stream<User?> get user => _auth.authStateChanges();

  // Get current Firebase user
  User? get currentUser => _auth.currentUser;

  AuthService() {
    // Initialize WidgetsBindingObserver to listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in
        _updateUserStatus(user.uid, true);
      } else {
        // User logged out or app terminated
        if (currentUser != null) { // Only update if there was a user before logout
          _updateUserStatus(currentUser!.uid, false);
        }
      }
    });
  }

  @override
  void dispose() {
    // No super.dispose() call needed as AuthService is not a State object
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      // App is in foreground
      _updateUserStatus(currentUser!.uid, true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // App is in background or terminated
      _updateUserStatus(currentUser!.uid, false);
    }
  }

  // Helper method to update user's online status in Firestore
  Future<void> _updateUserStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Use merge to only update these fields
      print('User $uid status updated: isOnline=$isOnline');
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  // Sign up with email and password (renamed from signUp)
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Initialize a basic user document in Firestore with default values
      // This is crucial for preventing missing fields and type errors later.
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': '', // Initialize as empty string
        'bio': '', // Initialize as empty string
        'profilePhotos': [], // Initialize as empty list
        'gender': '', // Initialize as empty string
        'college': '', // Initialize as empty string
        'age': null, // Initialize as null or a default int if you prefer
        'location': null, // Initialize as null to avoid String to GeoPoint errors
        'fcmToken': null, // Will be updated by UserService later
        'boostEndTime': null,
        'likedUsers': [],
        'dislikedUsers': [],
        'matches': [],
        'blockedUsers': [],
        'reportedByUsers': [],
        'interests': [],
        'education': '',
        'prompts': {},
        'genderPreference': 'Both',
        'minAgePreference': 18,
        'maxAgePreference': 30,
        'maxDistancePreference': 50.0,
        'isOnline': true, // Set online immediately after signup
        'lastActive': FieldValue.serverTimestamp(),
      });

      // Send email verification link
      await userCredential.user!.sendEmailVerification(); // Added this line
      print('Email verification sent to ${email}'); // Added this line

      return userCredential.user?.uid; // Return UID upon successful signup
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during signup: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error during signup: $e');
      rethrow;
    }
  }

  // Sign in with email and password (renamed from signIn)
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Update user's online status after successful login
      await _updateUserStatus(userCredential.user!.uid, true);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during signin: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error during signin: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (currentUser != null) {
        await _updateUserStatus(currentUser!.uid, false); // Set offline before signing out
      }
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  // Method to reload user to check email verification status
  Future<void> reloadUser() async { // Added this method
    await _auth.currentUser?.reload(); // Added this method
  } // Added this method
}