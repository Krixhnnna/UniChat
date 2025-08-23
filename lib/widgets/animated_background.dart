// lib/widgets/animated_background.dart
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget
      child; // The content that will be placed on top of the background

  const AnimatedBackground({Key? key, required this.child}) : super(key: key);

  @override
  _AnimatedBackgroundState createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: widget.child,
    );
  }
}
