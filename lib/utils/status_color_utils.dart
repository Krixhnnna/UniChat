import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:campus_crush/models/user_model.dart';

class StatusColorUtils {
  static Color getStatusColor(User user) {
    if (user.isOnline == true) {
      return Colors.green;
    }

    if (user.lastActive != null) {
      final now = DateTime.now();
      DateTime lastSeen;

      if (user.lastActive is Timestamp) {
        lastSeen = (user.lastActive as Timestamp).toDate();
      } else if (user.lastActive is DateTime) {
        lastSeen = user.lastActive as DateTime;
      } else {
        return Colors.grey;
      }

      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 30) {
        return Colors.yellow;
      }
    }
    return Colors.grey;
  }

  static Color getStatusColorFromData(Map<String, dynamic>? data) {
    if (data == null) return Colors.grey;

    final isOnline = data['isOnline'] as bool? ?? false;
    if (isOnline) {
      return Colors.green;
    }

    final lastActive =
        data['lastActive'] ?? data['lastSeen'] ?? data['lastActiveTime'];
    if (lastActive != null) {
      final now = DateTime.now();
      DateTime lastSeen;

      if (lastActive is Timestamp) {
        lastSeen = lastActive.toDate();
      } else if (lastActive is DateTime) {
        lastSeen = lastActive;
      } else {
        return Colors.grey;
      }

      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 30) {
        return Colors.yellow;
      }
    }
    return Colors.grey;
  }
}
