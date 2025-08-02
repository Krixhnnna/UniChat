// lib/widgets/animated_background.dart
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child; // The content that will be placed on top of the background

  const AnimatedBackground({Key? key, required this.child}) : super(key: key);

  @override
  _AnimatedBackgroundState createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation1;
  late Animation<Color?> _colorAnimation2;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10), // Duration of one full animation cycle
      vsync: this,
    )..repeat(reverse: true); // Repeat animation back and forth

    // Define the sequence of colors for the gradient
    _colorAnimation1 = ColorTween(
      begin: Colors.blue.shade800,
      end: Colors.purple.shade800,
    ).animate(_animationController);

    _colorAnimation2 = ColorTween(
      begin: Colors.purple.shade800,
      end: Colors.red.shade800,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _colorAnimation1.value!,
                _colorAnimation2.value!,
              ],
            ),
          ),
          child: widget.child, // Place the content on top
        );
      },
    );
  }
}