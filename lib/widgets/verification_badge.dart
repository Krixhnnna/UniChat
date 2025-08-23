import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final double size;
  final Color? color;

  const VerificationBadge({
    Key? key,
    required this.isVerified,
    this.size = 16.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    // Temporarily use a simple icon for testing
    return Icon(
      Icons.verified,
      size: size,
      color: color ?? const Color(0xFFCA7AFF), // Purple color
    );
  }
}
