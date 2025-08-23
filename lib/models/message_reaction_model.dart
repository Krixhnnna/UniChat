// lib/models/message_reaction_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String reaction;
  final DateTime timestamp;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reaction,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'userId': userId,
      'reaction': reaction,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory MessageReaction.fromMap(Map<String, dynamic> data, {String? id}) {
    return MessageReaction(
      id: id ?? '',
      messageId: data['messageId'] ?? '',
      userId: data['userId'] ?? '',
      reaction: data['reaction'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  MessageReaction copyWith({
    String? id,
    String? messageId,
    String? userId,
    String? reaction,
    DateTime? timestamp,
  }) {
    return MessageReaction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      reaction: reaction ?? this.reaction,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageReaction &&
        other.id == id &&
        other.messageId == messageId &&
        other.userId == userId &&
        other.reaction == reaction;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        messageId.hashCode ^
        userId.hashCode ^
        reaction.hashCode;
  }
}

// Available reactions
class ReactionTypes {
  static const String like = '👍';
  static const String love = '❤️';
  static const String laugh = '😂';
  static const String wow = '😮';
  static const String sad = '😢';
  static const String angry = '😡';
  static const String fire = '🔥';
  static const String heart = '💜';

  static const List<String> allReactions = [
    like,
    love,
    laugh,
    wow,
    sad,
    angry,
    fire,
    heart,
  ];

  static String getReactionName(String reaction) {
    switch (reaction) {
      case like:
        return 'Like';
      case love:
        return 'Love';
      case laugh:
        return 'Laugh';
      case wow:
        return 'Wow';
      case sad:
        return 'Sad';
      case angry:
        return 'Angry';
      case fire:
        return 'Fire';
      case heart:
        return 'Heart';
      default:
        return 'Unknown';
    }
  }
}
