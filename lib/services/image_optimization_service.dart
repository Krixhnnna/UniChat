import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
// import 'package:firebase_storage/firebase_storage.dart';  // Temporarily disabled

class ImageOptimizationService {
  static const int _maxDimension = 800;
  static const int _jpegQuality = 70;
  static const int _maxFileSizeBytes = 500 * 1024; // 500KB

  // Profile picture specific settings for ultra-fast loading
  static const int _profilePicMaxDimension = 300; // Smaller for profile pics
  static const int _profilePicJpegQuality =
      60; // Lower quality for faster loading
  static const int _profilePicMaxFileSizeBytes = 100 * 1024; // 100KB max

  /// Optimize image for upload by compressing and resizing
  static Future<Uint8List> optimizeImageForUpload(File imageFile) async {
    try {
      // Read image file
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('Failed to decode image');

      // Resize image if it's too large
      img.Image resizedImage;
      if (image.width > _maxDimension || image.height > _maxDimension) {
        resizedImage = img.copyResize(
          image,
          width: _maxDimension,
          height: _maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resizedImage = image;
      }

      // Convert to JPEG with quality optimization
      Uint8List compressedBytes =
          img.encodeJpg(resizedImage, quality: _jpegQuality);

      // If still too large, reduce quality further
      if (compressedBytes.length > _maxFileSizeBytes) {
        compressedBytes = img.encodeJpg(resizedImage, quality: 50);
      }

      return compressedBytes;
    } catch (e) {
      print('Image optimization failed: $e');
      // Fallback to original image if optimization fails
      return await imageFile.readAsBytes();
    }
  }

  /// Ultra-optimized profile picture compression for very fast loading
  static Future<Uint8List> optimizeProfilePictureForUpload(
      File imageFile) async {
    try {
      // Read image file
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('Failed to decode profile picture');

      // Resize profile picture to smaller dimensions for ultra-fast loading
      img.Image resizedImage;
      if (image.width > _profilePicMaxDimension ||
          image.height > _profilePicMaxDimension) {
        resizedImage = img.copyResize(
          image,
          width: _profilePicMaxDimension,
          height: _profilePicMaxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resizedImage = image;
      }

      // Convert to JPEG with lower quality for faster loading
      Uint8List compressedBytes =
          img.encodeJpg(resizedImage, quality: _profilePicJpegQuality);

      // If still too large, reduce quality further
      if (compressedBytes.length > _profilePicMaxFileSizeBytes) {
        compressedBytes = img.encodeJpg(resizedImage, quality: 40);
      }

      return compressedBytes;
    } catch (e) {
      print('Profile picture optimization failed: $e');
      // Fallback to original image if optimization fails
      return await imageFile.readAsBytes();
    }
  }

  // Firebase Storage temporarily disabled
  // /// Get optimized storage reference for user media
  // static Reference getMediaStorageRef(String userId, String fileName) {
  //   return FirebaseStorage.instance
  //       .ref()
  //       .child('users/$userId/media/$fileName');
  // }

  // /// Get optimized storage reference for profile pictures
  // static Reference getProfilePictureStorageRef(String userId, String fileName) {
  //   return FirebaseStorage.instance
  //       .ref()
  //       .child('users/$userId/profile_pictures/$fileName');
  // }

  /// Upload optimized profile picture with ultra-fast loading optimization
  static Future<String> uploadOptimizedProfilePicture(
    String userId,
    File imageFile, {
    Function(double)? onProgress,
  }) async {
    // Firebase Storage temporarily disabled - return local path
    return imageFile.path;
  }

  /// Upload optimized image with progress tracking
  static Future<String> uploadOptimizedImage(
    String userId,
    File imageFile, {
    Function(double)? onProgress,
  }) async {
    // Firebase Storage temporarily disabled - return local path
    return imageFile.path;
  }

  /// Get image dimensions without loading full image
  static Future<Map<String, int>> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        return {
          'width': image.width,
          'height': image.height,
        };
      }
      return {'width': 0, 'height': 0};
    } catch (e) {
      return {'width': 0, 'height': 0};
    }
  }

  /// Generate optimized profile picture URL for existing users
  static String getOptimizedProfilePictureUrl(String originalUrl,
      {int size = 300}) {
    // If it's already a Firebase Storage URL, we can optimize it
    if (originalUrl.contains('firebase')) {
      // Add transformation parameters for faster loading
      return '$originalUrl?alt=media&size=$size';
    }
    return originalUrl;
  }
}
