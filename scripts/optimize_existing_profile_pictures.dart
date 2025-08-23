import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

// This script optimizes existing profile pictures for faster loading
// Run this script to compress all existing profile pictures

class ProfilePictureOptimizer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> optimizeAllProfilePictures() async {
    try {
      print('Starting profile picture optimization...');

      // Get all users with profile photos
      final usersSnapshot = await _firestore.collection('users').get();
      int processedCount = 0;
      int optimizedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final profilePhotos =
            List<String>.from(userData['profilePhotos'] ?? []);

        if (profilePhotos.isNotEmpty) {
          processedCount++;
          print('Processing user: ${userData['displayName'] ?? userDoc.id}');

          // Optimize each profile photo
          for (int i = 0; i < profilePhotos.length; i++) {
            final originalUrl = profilePhotos[i];
            try {
              final optimizedUrl = await _optimizeProfilePicture(
                userDoc.id,
                originalUrl,
                i,
              );

              if (optimizedUrl != null) {
                // Update user document with optimized URL
                await _firestore.collection('users').doc(userDoc.id).update({
                  'profilePhotos': FieldValue.arrayRemove([originalUrl])
                });

                await _firestore.collection('users').doc(userDoc.id).update({
                  'profilePhotos': FieldValue.arrayUnion([optimizedUrl])
                });

                optimizedCount++;
                print('  ✓ Optimized profile photo $i');
              }
            } catch (e) {
              print('  ✗ Failed to optimize profile photo $i: $e');
            }
          }
        }
      }

      print('\nOptimization complete!');
      print('Processed users: $processedCount');
      print('Optimized photos: $optimizedCount');
    } catch (e) {
      print('Error during optimization: $e');
    }
  }

  Future<String?> _optimizeProfilePicture(
    String userId,
    String originalUrl,
    int photoIndex,
  ) async {
    try {
      // Download original image
      final originalRef = _storage.refFromURL(originalUrl);
      final originalBytes = await originalRef.getData();

      if (originalBytes == null) return null;

      // Decode and optimize image
      final image = img.decodeImage(originalBytes);
      if (image == null) return null;

      // Resize to 300x300 for ultra-fast loading
      final resizedImage = img.copyResize(
        image,
        width: 300,
        height: 300,
        interpolation: img.Interpolation.linear,
      );

      // Compress with 60% quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: 60);

      // Upload optimized image
      final fileName =
          'profile_${userId}_${photoIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          _storage.ref().child('users/$userId/profile_pictures/$fileName');

      final uploadTask = storageRef.putData(
        compressedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'type': 'optimized_profile_picture',
            'originalSize': originalBytes.length.toString(),
            'optimizedSize': compressedBytes.length.toString(),
            'dimensions': '300x300',
            'optimizedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Delete original if it's in our storage
      if (originalUrl.contains('firebase')) {
        try {
          await originalRef.delete();
        } catch (e) {
          print('Could not delete original: $e');
        }
      }

      return downloadUrl;
    } catch (e) {
      print('Error optimizing profile picture: $e');
      return null;
    }
  }
}

void main() async {
  // Initialize Firebase (you'll need to set up Firebase Admin SDK)
  print('Profile Picture Optimizer');
  print(
      'This script will optimize all existing profile pictures for faster loading');
  print('Make sure you have Firebase Admin SDK configured');

  final optimizer = ProfilePictureOptimizer();
  await optimizer.optimizeAllProfilePictures();
}

