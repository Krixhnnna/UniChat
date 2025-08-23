import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedProfilePicture extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final double? size;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxBorder? border;
  final Color? backgroundColor;

  const OptimizedProfilePicture({
    Key? key,
    required this.imageUrl,
    this.radius = 20,
    this.size,
    this.placeholder,
    this.errorWidget,
    this.border,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? (radius * 2);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? const Color(0xFF2C2C2E),
        backgroundImage: const AssetImage('assets/defaultpfp.png'),
        child: placeholder,
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? const Color(0xFF2C2C2E),
          child: const CircularProgressIndicator(
            color: Color(0xFF895BE0),
            strokeWidth: 2,
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? const Color(0xFF2C2C2E),
          backgroundImage: const AssetImage('assets/defaultpfp.png'),
        ),
      ),
    );
  }
}

class OptimizedProfilePictureWithBorder extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final double? size;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  const OptimizedProfilePictureWithBorder({
    Key? key,
    required this.imageUrl,
    this.radius = 20,
    this.size,
    this.placeholder,
    this.errorWidget,
    this.borderColor = Colors.white,
    this.borderWidth = 2.0,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: OptimizedProfilePicture(
        imageUrl: imageUrl,
        radius: radius,
        size: size,
        placeholder: placeholder,
        errorWidget: errorWidget,
        backgroundColor: backgroundColor,
      ),
    );
  }
}
