// lib/services/image_compression_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressionService {
  static const int _maxWidth = 1080;
  static const int _maxHeight = 1080;
  static const int _quality = 85;
  static const int _maxFileSizeKB = 500; // 500KB max file size

  /// Compress an image file for optimal uploading
  static Future<File> compressImage(File originalFile) async {
    try {
      // Read the original image
      final Uint8List imageBytes = await originalFile.readAsBytes();

      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Unable to decode image');
      }

      // Resize if necessary
      if (image.width > _maxWidth || image.height > _maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? _maxWidth : null,
          height: image.height > image.width ? _maxHeight : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress to JPEG with quality setting
      final Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: _quality),
      );

      // If still too large, reduce quality further
      Uint8List finalBytes = compressedBytes;
      int currentQuality = _quality;

      while (finalBytes.length > _maxFileSizeKB * 1024 && currentQuality > 20) {
        currentQuality -= 10;
        finalBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: currentQuality),
        );
      }

      // Save to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final File compressedFile = File(path.join(tempDir.path, fileName));

      await compressedFile.writeAsBytes(finalBytes);

      print(
          'Image compressed: ${originalFile.lengthSync()} bytes -> ${compressedFile.lengthSync()} bytes');

      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      // Return original file if compression fails
      return originalFile;
    }
  }

  /// Get optimized image dimensions
  static Map<String, int> getOptimizedDimensions(
      int originalWidth, int originalHeight) {
    if (originalWidth <= _maxWidth && originalHeight <= _maxHeight) {
      return {'width': originalWidth, 'height': originalHeight};
    }

    double aspectRatio = originalWidth / originalHeight;

    int newWidth, newHeight;
    if (originalWidth > originalHeight) {
      newWidth = _maxWidth;
      newHeight = (newWidth / aspectRatio).round();
    } else {
      newHeight = _maxHeight;
      newWidth = (newHeight * aspectRatio).round();
    }

    return {'width': newWidth, 'height': newHeight};
  }

  /// Compress image for profile pictures (smaller size)
  static Future<File> compressProfileImage(File originalFile) async {
    try {
      final Uint8List imageBytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Unable to decode image');
      }

      // Profile pictures should be square and smaller
      const int profileSize = 512;

      // Make it square by cropping
      int size = image.width < image.height ? image.width : image.height;
      image = img.copyCrop(
        image,
        x: (image.width - size) ~/ 2,
        y: (image.height - size) ~/ 2,
        width: size,
        height: size,
      );

      // Resize to profile size
      image = img.copyResize(
        image,
        width: profileSize,
        height: profileSize,
        interpolation: img.Interpolation.linear,
      );

      // Compress to JPEG
      final Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: 90), // Higher quality for profile pics
      );

      // Save to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_profile.jpg';
      final File compressedFile = File(path.join(tempDir.path, fileName));

      await compressedFile.writeAsBytes(compressedBytes);

      print(
          'Profile image compressed: ${originalFile.lengthSync()} bytes -> ${compressedFile.lengthSync()} bytes');

      return compressedFile;
    } catch (e) {
      print('Error compressing profile image: $e');
      return originalFile;
    }
  }

  /// Generate thumbnail for images
  static Future<File> generateThumbnail(File originalFile) async {
    try {
      final Uint8List imageBytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Unable to decode image');
      }

      // Create small thumbnail
      const int thumbnailSize = 200;
      image = img.copyResize(
        image,
        width: thumbnailSize,
        height: thumbnailSize,
        interpolation: img.Interpolation.linear,
      );

      // Compress heavily for thumbnail
      final Uint8List thumbnailBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: 60),
      );

      // Save to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg';
      final File thumbnailFile = File(path.join(tempDir.path, fileName));

      await thumbnailFile.writeAsBytes(thumbnailBytes);

      return thumbnailFile;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return originalFile;
    }
  }

  /// Clean up temporary compressed files
  static Future<void> cleanupTempFiles() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final List<FileSystemEntity> files = tempDir.listSync();

      for (final file in files) {
        if (file is File &&
            (file.path.contains('_compressed.jpg') ||
                file.path.contains('_profile.jpg') ||
                file.path.contains('_thumb.jpg'))) {
          // Delete files older than 1 hour
          final DateTime fileModified = await file.lastModified();
          final Duration age = DateTime.now().difference(fileModified);

          if (age.inHours > 1) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }
}
