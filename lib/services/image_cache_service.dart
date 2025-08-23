import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, Image> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);
  static const int _maxCacheSize = 100;

  // Preload images for better performance
  Future<void> preloadImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      if (!_memoryCache.containsKey(url)) {
        try {
          final image = await _loadAndCacheImage(url);
          if (image != null) {
            _addToCache(url, image);
          }
        } catch (e) {
          print('Error preloading image: $e');
        }
      }
    }
  }

  Future<Image?> _loadAndCacheImage(String url) async {
    try {
      final cacheManager = DefaultCacheManager();
      final fileInfo = await cacheManager.getFileFromCache(url);

      if (fileInfo != null) {
        final bytes = await fileInfo.file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 400,
          cacheHeight: 600,
        );
      } else {
        // Download and cache
        final fileInfo = await cacheManager.downloadFile(url);
        final bytes = await fileInfo.file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 400,
          cacheHeight: 600,
        );
      }
    } catch (e) {
      print('Error loading image: $e');
      return null;
    }
  }

  void _addToCache(String key, Image image) {
    // Remove oldest entries if cache is full
    if (_memoryCache.length >= _maxCacheSize) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _memoryCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }

    _memoryCache[key] = image;
    _cacheTimestamps[key] = DateTime.now();
  }

  Image? getCachedImage(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) < _cacheExpiry) {
      return _memoryCache[key];
    }

    // Remove expired cache entry
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    return null;
  }

  void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
  }

  // Optimized network image widget with caching
  Widget getOptimizedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF895BE0)),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.grey),
          ),
      memCacheWidth: (width * 2).round(), // Optimize memory usage
      memCacheHeight: (height * 2).round(),
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 1200,
    );
  }
}
