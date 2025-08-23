// lib/widgets/voice_message_widget.dart
import 'package:flutter/material.dart';
import '../services/voice_message_service.dart';
import 'dart:math' as math;
import 'dart:async';

class VoiceMessageWidget extends StatefulWidget {
  final String messageId;
  final String? audioUrl;
  final Duration? duration;
  final bool isOwnMessage;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;

  const VoiceMessageWidget({
    Key? key,
    required this.messageId,
    this.audioUrl,
    this.duration,
    this.isOwnMessage = false,
    this.onPlay,
    this.onPause,
  }) : super(key: key);

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget>
    with TickerProviderStateMixin {
  final VoiceMessageService _voiceService = VoiceMessageService();
  late AnimationController _waveAnimationController;
  late Animation<double> _waveAnimation;

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveAnimationController,
      curve: Curves.easeInOut,
    ));

    _totalDuration = widget.duration ?? Duration.zero;

    // Start wave animation on repeat when playing
    _waveAnimationController.repeat();
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    if (widget.audioUrl == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isPlaying) {
        await _voiceService.pauseVoiceMessage(widget.messageId);
        _waveAnimationController.stop();
        widget.onPause?.call();
      } else {
        await _voiceService.playVoiceMessage(
            widget.messageId, widget.audioUrl!);
        _waveAnimationController.repeat();
        widget.onPlay?.call();
      }

      setState(() {
        _isPlaying = !_isPlaying;
      });
    } catch (e) {
      print('Error toggling voice message playback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing voice message: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 250,
      ),
      decoration: BoxDecoration(
        color: widget.isOwnMessage
            ? const Color(0xFF8B5CF6)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause button
              InkWell(
                onTap: _togglePlayback,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.isOwnMessage
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isOwnMessage ? Colors.white : Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color:
                              widget.isOwnMessage ? Colors.white : Colors.white,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Waveform and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform visualization
                    SizedBox(
                      height: 30,
                      child: AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: WaveformPainter(
                              progress: progress,
                              isPlaying: _isPlaying,
                              animationValue: _waveAnimation.value,
                              waveColor: widget.isOwnMessage
                                  ? Colors.white.withOpacity(0.6)
                                  : const Color(0xFF8B5CF6).withOpacity(0.6),
                              progressColor: widget.isOwnMessage
                                  ? Colors.white
                                  : const Color(0xFF8B5CF6),
                            ),
                            size: const Size(double.infinity, 30),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Duration
                    Text(
                      _voiceService.formatDuration(_totalDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isOwnMessage
                            ? Colors.white.withOpacity(0.8)
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double animationValue;
  final Color waveColor;
  final Color progressColor;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.animationValue,
    required this.waveColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barCount = 30;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;

      // Generate wave pattern
      double baseHeight = (math.sin(i * 0.3) + 1) / 2;
      baseHeight = baseHeight * 0.5 + 0.3; // Scale between 0.3 and 0.8

      // Add animation effect when playing
      if (isPlaying) {
        final animationOffset =
            math.sin(animationValue * 2 * math.pi + i * 0.5);
        baseHeight += animationOffset * 0.2;
      }

      final barHeight = size.height * baseHeight;
      final startY = centerY - barHeight / 2;
      final endY = centerY + barHeight / 2;

      // Use progress color if this bar is before the current progress
      final shouldUseProgressColor = (i / barCount) <= progress;
      final currentPaint = shouldUseProgressColor ? progressPaint : paint;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration) onRecordingComplete;
  final VoidCallback? onRecordingCancelled;

  const VoiceRecorderWidget({
    Key? key,
    required this.onRecordingComplete,
    this.onRecordingCancelled,
  }) : super(key: key);

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  final VoiceMessageService _voiceService = VoiceMessageService();

  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startRecording() async {
    try {
      final hasPermission = await _voiceService.checkMicrophonePermission();
      if (!hasPermission) {
        final granted = await _voiceService.requestMicrophonePermission();
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')),
          );
          return;
        }
      }

      await _voiceService.startRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _pulseController.repeat(reverse: true);

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  void _stopRecording() async {
    try {
      final audioPath = await _voiceService.stopRecording();

      setState(() {
        _isRecording = false;
      });

      _pulseController.stop();
      _durationTimer?.cancel();

      if (audioPath != null) {
        widget.onRecordingComplete(audioPath, _recordingDuration);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  void _cancelRecording() async {
    try {
      await _voiceService.cancelRecording();

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      _pulseController.stop();
      _durationTimer?.cancel();

      widget.onRecordingCancelled?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return InkWell(
        onTap: _startRecording,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cancel button
          InkWell(
            onTap: _cancelRecording,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Recording indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            _voiceService.formatDuration(_recordingDuration),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 8),

          // Stop button
          InkWell(
            onTap: _stopRecording,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
