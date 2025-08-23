// lib/services/voice_message_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';

class VoiceMessageService {
  static final VoiceMessageService _instance = VoiceMessageService._internal();
  factory VoiceMessageService() => _instance;
  VoiceMessageService._internal();

  // For recording, we would use flutter_sound or record package
  // bool _isRecording = false;
  // FlutterSoundRecorder? _recorder;
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, bool> _playingStates = {};
  final Map<String, Duration> _durations = {};
  final Map<String, Duration> _positions = {};

  // Initialize voice message service
  Future<void> initialize() async {
    try {
      // Initialize audio players
      print('Voice message service initialized');
    } catch (e) {
      print('Error initializing voice message service: $e');
    }
  }

  // Start recording (placeholder - would need flutter_sound or record package)
  Future<void> startRecording() async {
    try {
      // In a real implementation, you would:
      // 1. Request microphone permission
      // 2. Initialize recorder
      // 3. Start recording
      print('Recording started (placeholder implementation)');
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }

  // Stop recording and return file path
  Future<String?> stopRecording() async {
    try {
      // In a real implementation, you would:
      // 1. Stop recording
      // 2. Get recorded file path
      // 3. Return file path

      // For now, return a placeholder path
      final directory = await getTemporaryDirectory();
      final filePath = path.join(
          directory.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

      print('Recording stopped (placeholder implementation): $filePath');
      return filePath;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      // In a real implementation, you would:
      // 1. Stop recording
      // 2. Delete temporary file
      print('Recording cancelled');
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  // Play voice message
  Future<void> playVoiceMessage(String messageId, String audioUrl) async {
    try {
      // Stop any currently playing audio
      await stopAllPlaying();

      // Create new audio player for this message
      final player = AudioPlayer();
      _audioPlayers[messageId] = player;

      // Set up listeners
      player.onDurationChanged.listen((duration) {
        _durations[messageId] = duration;
      });

      player.onPositionChanged.listen((position) {
        _positions[messageId] = position;
      });

      player.onPlayerComplete.listen((_) {
        _playingStates[messageId] = false;
        _positions[messageId] = Duration.zero;
        player.dispose();
        _audioPlayers.remove(messageId);
      });

      // Start playing
      await player.play(UrlSource(audioUrl));
      _playingStates[messageId] = true;

      print('Playing voice message: $messageId');
    } catch (e) {
      print('Error playing voice message: $e');
      _playingStates[messageId] = false;
    }
  }

  // Pause voice message
  Future<void> pauseVoiceMessage(String messageId) async {
    try {
      final player = _audioPlayers[messageId];
      if (player != null) {
        await player.pause();
        _playingStates[messageId] = false;
        print('Paused voice message: $messageId');
      }
    } catch (e) {
      print('Error pausing voice message: $e');
    }
  }

  // Resume voice message
  Future<void> resumeVoiceMessage(String messageId) async {
    try {
      final player = _audioPlayers[messageId];
      if (player != null) {
        await player.resume();
        _playingStates[messageId] = true;
        print('Resumed voice message: $messageId');
      }
    } catch (e) {
      print('Error resuming voice message: $e');
    }
  }

  // Stop voice message
  Future<void> stopVoiceMessage(String messageId) async {
    try {
      final player = _audioPlayers[messageId];
      if (player != null) {
        await player.stop();
        _playingStates[messageId] = false;
        _positions[messageId] = Duration.zero;
        player.dispose();
        _audioPlayers.remove(messageId);
        print('Stopped voice message: $messageId');
      }
    } catch (e) {
      print('Error stopping voice message: $e');
    }
  }

  // Stop all playing voice messages
  Future<void> stopAllPlaying() async {
    try {
      final playingMessages = _audioPlayers.keys.toList();
      for (final messageId in playingMessages) {
        await stopVoiceMessage(messageId);
      }
    } catch (e) {
      print('Error stopping all voice messages: $e');
    }
  }

  // Seek to position
  Future<void> seekTo(String messageId, Duration position) async {
    try {
      final player = _audioPlayers[messageId];
      if (player != null) {
        await player.seek(position);
        print('Seeked to ${position.inSeconds}s in message: $messageId');
      }
    } catch (e) {
      print('Error seeking voice message: $e');
    }
  }

  // Get playing state
  bool isPlaying(String messageId) {
    return _playingStates[messageId] ?? false;
  }

  // Get duration
  Duration getDuration(String messageId) {
    return _durations[messageId] ?? Duration.zero;
  }

  // Get current position
  Duration getPosition(String messageId) {
    return _positions[messageId] ?? Duration.zero;
  }

  // Get playback progress (0.0 to 1.0)
  double getProgress(String messageId) {
    final duration = getDuration(messageId);
    final position = getPosition(messageId);

    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  // Format duration for display
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get file size of voice message
  Future<String> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();

      if (bytes < 1024) {
        return '${bytes}B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)}KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Compress voice message (placeholder)
  Future<String?> compressVoiceMessage(String inputPath) async {
    try {
      // In a real implementation, you would compress the audio file
      // For now, just return the original path
      print('Voice message compression (placeholder): $inputPath');
      return inputPath;
    } catch (e) {
      print('Error compressing voice message: $e');
      return null;
    }
  }

  // Generate waveform data (placeholder)
  Future<List<double>> generateWaveform(String audioPath) async {
    try {
      // In a real implementation, you would analyze the audio file
      // and generate waveform data points

      // For now, generate fake waveform data
      final waveform = <double>[];
      for (int i = 0; i < 50; i++) {
        waveform.add((i % 10) / 10.0);
      }
      return waveform;
    } catch (e) {
      print('Error generating waveform: $e');
      return [];
    }
  }

  // Clean up resources
  Future<void> dispose() async {
    try {
      await stopAllPlaying();
      for (final player in _audioPlayers.values) {
        await player.dispose();
      }
      _audioPlayers.clear();
      _playingStates.clear();
      _durations.clear();
      _positions.clear();
      print('Voice message service disposed');
    } catch (e) {
      print('Error disposing voice message service: $e');
    }
  }

  // Check microphone permission (placeholder)
  Future<bool> checkMicrophonePermission() async {
    try {
      // In a real implementation, you would check microphone permission
      // For now, assume permission is granted
      return true;
    } catch (e) {
      print('Error checking microphone permission: $e');
      return false;
    }
  }

  // Request microphone permission (placeholder)
  Future<bool> requestMicrophonePermission() async {
    try {
      // In a real implementation, you would request microphone permission
      // For now, assume permission is granted
      return true;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }
}

// Voice message state for UI
class VoiceMessageState {
  final bool isRecording;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final double volume;
  final String? error;

  const VoiceMessageState({
    this.isRecording = false,
    this.isPlaying = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.volume = 1.0,
    this.error,
  });

  VoiceMessageState copyWith({
    bool? isRecording,
    bool? isPlaying,
    Duration? duration,
    Duration? position,
    double? volume,
    String? error,
  }) {
    return VoiceMessageState(
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      volume: volume ?? this.volume,
      error: error ?? this.error,
    );
  }
}
