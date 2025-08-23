// lib/services/cdn_service.dart

class CDNService {
  // Firebase Storage bucket with CDN
  static const String _firebaseStorageDomain = 'firebasestorage.googleapis.com';
  static const String _projectId =
      'collegecrush-eec15'; // Update with your project ID

  // Image optimization parameters
  static const Map<String, String> _thumbnailParams = {
    'w': '300', // width
    'h': '300', // height
    'c': 'fill', // crop mode
    'q': '80', // quality
    'f': 'webp', // format (fallback to original if not supported)
  };

  static const Map<String, String> _mediumParams = {
    'w': '800',
    'h': '600',
    'c': 'fit',
    'q': '85',
    'f': 'webp',
  };

  static const Map<String, String> _profileParams = {
    'w': '400',
    'h': '400',
    'c': 'fill',
    'q': '90',
    'f': 'webp',
  };

  /// Get optimized image URL for different use cases
  static String getOptimizedImageUrl(
    String originalUrl, {
    ImageSize size = ImageSize.medium,
    bool webpFallback = true,
  }) {
    if (!originalUrl.contains(_firebaseStorageDomain)) {
      return originalUrl; // Return as-is if not Firebase Storage
    }

    try {
      final uri = Uri.parse(originalUrl);
      final Map<String, String> params;

      switch (size) {
        case ImageSize.thumbnail:
          params = _thumbnailParams;
          break;
        case ImageSize.medium:
          params = _mediumParams;
          break;
        case ImageSize.profile:
          params = _profileParams;
          break;
        case ImageSize.original:
          return originalUrl;
      }

      // Create new query parameters
      final newParams = Map<String, String>.from(uri.queryParameters);
      params.forEach((key, value) {
        newParams[key] = value;
      });

      // If WebP is not supported, remove format parameter
      if (!webpFallback) {
        newParams.remove('f');
      }

      // Build optimized URL
      final optimizedUri = uri.replace(queryParameters: newParams);
      return optimizedUri.toString();
    } catch (e) {
      print('Error optimizing image URL: $e');
      return originalUrl;
    }
  }

  /// Get responsive image URLs for different screen densities
  static Map<String, String> getResponsiveImageUrls(String originalUrl) {
    return {
      '1x': getOptimizedImageUrl(originalUrl, size: ImageSize.medium),
      '2x': getOptimizedImageUrl(originalUrl, size: ImageSize.original),
      'thumbnail': getOptimizedImageUrl(originalUrl, size: ImageSize.thumbnail),
      'profile': getOptimizedImageUrl(originalUrl, size: ImageSize.profile),
    };
  }

  /// Check if device supports WebP format
  static bool get supportsWebP {
    // Most modern devices support WebP
    // You can implement more sophisticated detection if needed
    return true;
  }

  /// Get image with cache headers for better performance
  static Map<String, String> getCacheHeaders() {
    return {
      'Cache-Control': 'public, max-age=31536000', // 1 year
      'Expires':
          DateTime.now().add(const Duration(days: 365)).toUtc().toString(),
    };
  }

  /// Preload critical images for better performance
  static Future<void> preloadImages(List<String> imageUrls) async {
    // In a real implementation, you would preload these images
    // For now, just optimize the URLs
    final optimizedUrls = imageUrls
        .map((url) => getOptimizedImageUrl(url, size: ImageSize.thumbnail))
        .toList();

    print('Preloading ${optimizedUrls.length} optimized images');
    // TODO: Implement actual image preloading
  }

  /// Generate image variants for upload
  static Map<String, String> generateImageVariants(String baseUrl) {
    return {
      'original': baseUrl,
      'large': getOptimizedImageUrl(baseUrl, size: ImageSize.original),
      'medium': getOptimizedImageUrl(baseUrl, size: ImageSize.medium),
      'thumbnail': getOptimizedImageUrl(baseUrl, size: ImageSize.thumbnail),
      'profile': getOptimizedImageUrl(baseUrl, size: ImageSize.profile),
    };
  }

  /// Build Firebase Storage URL with custom domain (if configured)
  static String buildStorageUrl({
    required String bucket,
    required String path,
    String? customDomain,
    Map<String, String>? queryParams,
  }) {
    final domain = customDomain ?? 'firebasestorage.googleapis.com';
    final baseUrl =
        'https://$domain/v0/b/$bucket/o/${Uri.encodeComponent(path)}';

    final defaultParams = {
      'alt': 'media',
    };

    if (queryParams != null) {
      defaultParams.addAll(queryParams);
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: defaultParams);
    return uri.toString();
  }

  /// Performance monitoring for image loading
  static void trackImageLoadTime(String imageUrl, Duration loadTime) {
    print('Image load time for $imageUrl: ${loadTime.inMilliseconds}ms');
    // TODO: Send to analytics service
  }

  /// Get optimal image size based on screen density
  static ImageSize getOptimalSize(double devicePixelRatio) {
    if (devicePixelRatio >= 3.0) {
      return ImageSize.original;
    } else if (devicePixelRatio >= 2.0) {
      return ImageSize.medium;
    } else {
      return ImageSize.thumbnail;
    }
  }
}

enum ImageSize {
  thumbnail,
  medium,
  profile,
  original,
}

/// CDN Configuration for different environments
class CDNConfig {
  static const String prodCdnDomain = 'cdn.yourapp.com';
  static const String devCdnDomain = 'dev-cdn.yourapp.com';

  static String get cdnDomain {
    // Return appropriate domain based on environment
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction ? prodCdnDomain : devCdnDomain;
  }

  static Map<String, dynamic> get cdnSettings {
    return {
      'domain': cdnDomain,
      'cacheMaxAge': 31536000, // 1 year
      'compressionEnabled': true,
      'webpEnabled': true,
      'gzipEnabled': true,
    };
  }
}
