import 'package:flutter/material.dart';
import 'dart:math' as math;

class SkeletonLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;
  final bool isShimmer;

  const SkeletonLoading({
    Key? key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 4,
    this.color,
    this.isShimmer = true,
  }) : super(key: key);

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isShimmer) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: widget.color ?? Colors.grey[800],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final pulseOpacity = 0.8 + (0.2 * math.sin(_animation.value * math.pi));

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                (widget.color ?? Colors.grey[800]!).withOpacity(pulseOpacity),
                (widget.color ?? Colors.grey[700]!).withOpacity(pulseOpacity),
                (widget.color ?? Colors.grey[600]!).withOpacity(pulseOpacity),
                (widget.color ?? Colors.grey[700]!).withOpacity(pulseOpacity),
                (widget.color ?? Colors.grey[800]!).withOpacity(pulseOpacity),
              ],
              stops: [
                0.0,
                0.3 + (_animation.value * 0.2),
                0.5 + (_animation.value * 0.3),
                0.7 + (_animation.value * 0.2),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? shimmerColor;

  const ShimmerSkeleton({
    Key? key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 4,
    this.baseColor,
    this.shimmerColor,
  }) : super(key: key);

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? Colors.grey[800]!;
    final shimmerColor = widget.shimmerColor ?? Colors.grey[600]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: baseColor,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          shimmerColor.withOpacity(0.4),
                          shimmerColor.withOpacity(0.6),
                          shimmerColor.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.3 + (_animation.value * 0.2),
                          0.5 + (_animation.value * 0.3),
                          0.7 + (_animation.value * 0.2),
                          1.0,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatSkeletonTile extends StatelessWidget {
  const ChatSkeletonTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Skeleton for profile picture
          ShimmerSkeleton(
            width: 48,
            height: 48,
            borderRadius: 24,
            baseColor: Colors.grey[800],
            shimmerColor: Colors.grey[600],
          ),
          const SizedBox(width: 16),
          // Skeleton for text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(
                  width: 120,
                  height: 16,
                  borderRadius: 8,
                  baseColor: Colors.grey[800],
                  shimmerColor: Colors.grey[600],
                ),
                const SizedBox(height: 8),
                ShimmerSkeleton(
                  width: 200,
                  height: 14,
                  borderRadius: 7,
                  baseColor: Colors.grey[800],
                  shimmerColor: Colors.grey[600],
                ),
              ],
            ),
          ),
          // Skeleton for trailing content
          ShimmerSkeleton(
            width: 40,
            height: 14,
            borderRadius: 7,
            baseColor: Colors.grey[800],
            shimmerColor: Colors.grey[600],
          ),
        ],
      ),
    );
  }
}

class UserCardSkeleton extends StatelessWidget {
  const UserCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Skeleton for profile picture
        ShimmerSkeleton(
          width: 70,
          height: 70,
          borderRadius: 35,
          baseColor: Colors.grey[800],
          shimmerColor: Colors.grey[600],
        ),
        const SizedBox(height: 8),
        // Skeleton for name
        ShimmerSkeleton(
          width: 60,
          height: 14,
          borderRadius: 7,
          baseColor: Colors.grey[800],
          shimmerColor: Colors.grey[600],
        ),
      ],
    );
  }
}
