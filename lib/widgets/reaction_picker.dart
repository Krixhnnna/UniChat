// lib/widgets/reaction_picker.dart
import 'package:flutter/material.dart';
import '../models/message_reaction_model.dart';

class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;
  final bool isOwnMessage;

  const ReactionPicker({
    Key? key,
    required this.onReactionSelected,
    this.isOwnMessage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ReactionTypes.allReactions.map((reaction) {
          return InkWell(
            onTap: () => onReactionSelected(reaction),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                reaction,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReactionDisplay extends StatelessWidget {
  final Map<String, List<MessageReaction>> reactions;
  final String currentUserId;
  final Function(String) onReactionTap;
  final bool isOwnMessage;

  const ReactionDisplay({
    Key? key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    this.isOwnMessage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.entries.map((entry) {
          final reaction = entry.key;
          final reactionList = entry.value;
          final hasCurrentUserReaction =
              reactionList.any((r) => r.userId == currentUserId);

          return InkWell(
            onTap: () => onReactionTap(reaction),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasCurrentUserReaction
                    ? const Color(0xFF8B5CF6).withOpacity(0.2)
                    : Theme.of(context).cardColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasCurrentUserReaction
                      ? const Color(0xFF8B5CF6)
                      : Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (reactionList.length > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      reactionList.length.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: hasCurrentUserReaction
                            ? const Color(0xFF8B5CF6)
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReactionButton extends StatefulWidget {
  final Function() onPressed;
  final bool isVisible;

  const ReactionButton({
    Key? key,
    required this.onPressed,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(ReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: widget.onPressed,
              icon: const Icon(
                Icons.add_reaction,
                color: Colors.white,
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        );
      },
    );
  }
}

// Reaction animation widget
class ReactionAnimation extends StatefulWidget {
  final String reaction;
  final Offset startPosition;
  final VoidCallback onComplete;

  const ReactionAnimation({
    Key? key,
    required this.reaction,
    required this.startPosition,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<ReactionAnimation> createState() => _ReactionAnimationState();
}

class _ReactionAnimationState extends State<ReactionAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -50),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startPosition.dx,
          top: widget.startPosition.dy + _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.reaction,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}
