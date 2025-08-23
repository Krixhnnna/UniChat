import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// This script should be run once to mark Krishna as the verified founder
// Run with: dart scripts/verify_founder.dart

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  try {
    // Find Krishna's user document by email
    final querySnapshot = await firestore
        .collection('users')
        .where('email', isEqualTo: 'krishna.12408588@lpu.in')
        .get();

    if (querySnapshot.docs.isEmpty) {
      print('❌ User with email krishna.12408588@lpu.in not found');
      return;
    }

    final userDoc = querySnapshot.docs.first;
    final userId = userDoc.id;

    // Update the user document to mark as verified and set role as founder
    await firestore.collection('users').doc(userId).update({
      'isVerified': true,
      'role': 'founder',
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    print(
        '✅ Successfully marked Krishna (${userDoc.data()['displayName'] ?? 'Unknown'}) as verified founder!');
    print('📧 Email: ${userDoc.data()['email']}');
    print('🆔 User ID: $userId');
  } catch (e) {
    print('❌ Error updating user: $e');
  }
}
