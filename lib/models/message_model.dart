// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDurationMs;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderId;
  final String? clientMessageId;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.isRead,
    this.isDelivered = false,
    this.imageUrl,
    this.audioUrl,
    this.audioDurationMs,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderId,
    this.clientMessageId,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    bool? isDelivered,
    String? imageUrl,
    String? audioUrl,
    int? audioDurationMs,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
    String? clientMessageId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDurationMs': audioDurationMs,
      'replyToMessageId': replyToMessageId,
      'replyToContent': replyToContent,
      'replyToSenderId': replyToSenderId,
      'clientMessageId': clientMessageId,
    };
  }

  factory Message.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime resolvedTimestamp;
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      resolvedTimestamp = ts.toDate();
    } else if (ts is String && ts.isNotEmpty) {
      resolvedTimestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else if (data['clientSentAt'] is String) {
      resolvedTimestamp =
          DateTime.tryParse(data['clientSentAt'] as String) ?? DateTime.now();
    } else {
      resolvedTimestamp = DateTime.now();
    }

    return Message(
      id: id ?? data['id'] ?? '',
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      timestamp: resolvedTimestamp,
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] as bool? ?? false,
      imageUrl: data['imageUrl'],
      audioUrl: data['audioUrl'],
      audioDurationMs: data['audioDurationMs'],
      replyToMessageId: data['replyToMessageId'],
      replyToContent: data['replyToContent'],
      replyToSenderId: data['replyToSenderId'],
      clientMessageId: data['clientMessageId'] as String?,
    );
  }
}
