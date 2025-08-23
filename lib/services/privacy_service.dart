// lib/services/privacy_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum ReadReceiptSetting {
  everyone, // Show read receipts to everyone
  matches, // Show read receipts only to matches
  nobody, // Don't show read receipts to anyone
}

enum OnlineStatusSetting {
  everyone, // Show online status to everyone
  matches, // Show online status only to matches
  nobody, // Don't show online status to anyone
}

enum LastSeenSetting {
  everyone, // Show last seen to everyone
  matches, // Show last seen only to matches
  nobody, // Don't show last seen to anyone
}

enum TypingIndicatorSetting {
  everyone, // Show typing indicator to everyone
  matches, // Show typing indicator only to matches
  nobody, // Don't show typing indicator to anyone
}

class PrivacyService {
  static final PrivacyService _instance = PrivacyService._internal();
  factory PrivacyService() => _instance;
  PrivacyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _readReceiptsKey = 'read_receipts_setting';
  static const String _onlineStatusKey = 'online_status_setting';
  static const String _lastSeenKey = 'last_seen_setting';
  static const String _typingIndicatorKey = 'typing_indicator_setting';
  static const String _profileVisibilityKey = 'profile_visibility_setting';
  static const String _blockListKey = 'blocked_users';

  // Privacy settings cache
  Map<String, dynamic> _privacySettings = {};
  bool _isInitialized = false;

  // Initialize privacy service
  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    try {
      await _loadPrivacySettings(userId);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing privacy service: $e');
    }
  }

  // Load privacy settings from Firestore and cache locally
  Future<void> _loadPrivacySettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('settings')
          .get();

      if (doc.exists) {
        _privacySettings = doc.data() ?? {};
      } else {
        // Set default settings if none exist
        _privacySettings = _getDefaultPrivacySettings();
        await _savePrivacySettings(userId);
      }
    } catch (e) {
      print('Error loading privacy settings: $e');
      _privacySettings = _getDefaultPrivacySettings();
    }
  }

  // Get default privacy settings
  Map<String, dynamic> _getDefaultPrivacySettings() {
    return {
      _readReceiptsKey: ReadReceiptSetting.everyone.name,
      _onlineStatusKey: OnlineStatusSetting.everyone.name,
      _lastSeenKey: LastSeenSetting.everyone.name,
      _typingIndicatorKey: TypingIndicatorSetting.everyone.name,
      _profileVisibilityKey: 'everyone',
      'showProfile': true,
      'allowMessages': true,
      'allowCalls': true,
      'showInDiscovery': true,
    };
  }

  // Save privacy settings to Firestore
  Future<void> _savePrivacySettings(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('settings')
          .set(_privacySettings, SetOptions(merge: true));
    } catch (e) {
      print('Error saving privacy settings: $e');
    }
  }

  // Read Receipt Settings
  Future<void> setReadReceiptSetting(
      String userId, ReadReceiptSetting setting) async {
    _privacySettings[_readReceiptsKey] = setting.name;
    await _savePrivacySettings(userId);
  }

  ReadReceiptSetting getReadReceiptSetting() {
    final settingName =
        _privacySettings[_readReceiptsKey] ?? ReadReceiptSetting.everyone.name;
    return ReadReceiptSetting.values.firstWhere(
      (e) => e.name == settingName,
      orElse: () => ReadReceiptSetting.everyone,
    );
  }

  // Online Status Settings
  Future<void> setOnlineStatusSetting(
      String userId, OnlineStatusSetting setting) async {
    _privacySettings[_onlineStatusKey] = setting.name;
    await _savePrivacySettings(userId);
  }

  OnlineStatusSetting getOnlineStatusSetting() {
    final settingName =
        _privacySettings[_onlineStatusKey] ?? OnlineStatusSetting.everyone.name;
    return OnlineStatusSetting.values.firstWhere(
      (e) => e.name == settingName,
      orElse: () => OnlineStatusSetting.everyone,
    );
  }

  // Last Seen Settings
  Future<void> setLastSeenSetting(
      String userId, LastSeenSetting setting) async {
    _privacySettings[_lastSeenKey] = setting.name;
    await _savePrivacySettings(userId);
  }

  LastSeenSetting getLastSeenSetting() {
    final settingName =
        _privacySettings[_lastSeenKey] ?? LastSeenSetting.everyone.name;
    return LastSeenSetting.values.firstWhere(
      (e) => e.name == settingName,
      orElse: () => LastSeenSetting.everyone,
    );
  }

  // Typing Indicator Settings
  Future<void> setTypingIndicatorSetting(
      String userId, TypingIndicatorSetting setting) async {
    _privacySettings[_typingIndicatorKey] = setting.name;
    await _savePrivacySettings(userId);
  }

  TypingIndicatorSetting getTypingIndicatorSetting() {
    final settingName = _privacySettings[_typingIndicatorKey] ??
        TypingIndicatorSetting.everyone.name;
    return TypingIndicatorSetting.values.firstWhere(
      (e) => e.name == settingName,
      orElse: () => TypingIndicatorSetting.everyone,
    );
  }

  // Check if user should see read receipts
  Future<bool> shouldShowReadReceipts({
    required String viewerUserId,
    required String targetUserId,
  }) async {
    try {
      final targetSettings = await _getUserPrivacySettings(targetUserId);
      final readReceiptSetting =
          targetSettings[_readReceiptsKey] ?? ReadReceiptSetting.everyone.name;

      switch (readReceiptSetting) {
        case 'everyone':
          return true;
        case 'matches':
          return await _areUsersMatched(viewerUserId, targetUserId);
        case 'nobody':
          return false;
        default:
          return true;
      }
    } catch (e) {
      print('Error checking read receipt visibility: $e');
      return true; // Default to showing
    }
  }

  // Check if user should see online status
  Future<bool> shouldShowOnlineStatus({
    required String viewerUserId,
    required String targetUserId,
  }) async {
    try {
      final targetSettings = await _getUserPrivacySettings(targetUserId);
      final onlineStatusSetting =
          targetSettings[_onlineStatusKey] ?? OnlineStatusSetting.everyone.name;

      switch (onlineStatusSetting) {
        case 'everyone':
          return true;
        case 'matches':
          return await _areUsersMatched(viewerUserId, targetUserId);
        case 'nobody':
          return false;
        default:
          return true;
      }
    } catch (e) {
      print('Error checking online status visibility: $e');
      return true;
    }
  }

  // Check if user should see last seen
  Future<bool> shouldShowLastSeen({
    required String viewerUserId,
    required String targetUserId,
  }) async {
    try {
      final targetSettings = await _getUserPrivacySettings(targetUserId);
      final lastSeenSetting =
          targetSettings[_lastSeenKey] ?? LastSeenSetting.everyone.name;

      switch (lastSeenSetting) {
        case 'everyone':
          return true;
        case 'matches':
          return await _areUsersMatched(viewerUserId, targetUserId);
        case 'nobody':
          return false;
        default:
          return true;
      }
    } catch (e) {
      print('Error checking last seen visibility: $e');
      return true;
    }
  }

  // Check if user should see typing indicator
  Future<bool> shouldShowTypingIndicator({
    required String viewerUserId,
    required String targetUserId,
  }) async {
    try {
      final targetSettings = await _getUserPrivacySettings(targetUserId);
      final typingIndicatorSetting = targetSettings[_typingIndicatorKey] ??
          TypingIndicatorSetting.everyone.name;

      switch (typingIndicatorSetting) {
        case 'everyone':
          return true;
        case 'matches':
          return await _areUsersMatched(viewerUserId, targetUserId);
        case 'nobody':
          return false;
        default:
          return true;
      }
    } catch (e) {
      print('Error checking typing indicator visibility: $e');
      return true;
    }
  }

  // Get user's privacy settings
  Future<Map<String, dynamic>> _getUserPrivacySettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('settings')
          .get();

      return doc.exists ? doc.data()! : _getDefaultPrivacySettings();
    } catch (e) {
      print('Error getting user privacy settings: $e');
      return _getDefaultPrivacySettings();
    }
  }

  // Check if two users are matched (have liked each other)
  Future<bool> _areUsersMatched(String user1Id, String user2Id) async {
    try {
      // Check if there's a match document between these users
      final matchQuery = await _firestore
          .collection('matches')
          .where('users', arrayContains: user1Id)
          .get();

      for (final doc in matchQuery.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        if (users.contains(user2Id)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking if users are matched: $e');
      return false;
    }
  }

  // Block/Unblock Users
  Future<void> blockUser(String userId, String blockedUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('blocked_users')
          .set({
        blockedUserId: {
          'blockedAt': FieldValue.serverTimestamp(),
          'isBlocked': true,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String userId, String blockedUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('blocked_users')
          .update({
        blockedUserId: FieldValue.delete(),
      });
    } catch (e) {
      print('Error unblocking user: $e');
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked(String userId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('blocked_users')
          .get();

      if (!doc.exists) return false;

      final blockedUsers = doc.data() ?? {};
      return blockedUsers.containsKey(targetUserId);
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  // Get blocked users list
  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('blocked_users')
          .get();

      if (!doc.exists) return [];

      final blockedUsers = doc.data() ?? {};
      return blockedUsers.keys.toList();
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }

  // Report User
  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
    List<String>? messageIds,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details,
        'messageIds': messageIds,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewedBy': null,
        'reviewedAt': null,
        'action': null,
      });
    } catch (e) {
      print('Error reporting user: $e');
    }
  }

  // Get all privacy settings for display
  Map<String, dynamic> getAllPrivacySettings() {
    return Map<String, dynamic>.from(_privacySettings);
  }

  // Reset privacy settings to default
  Future<void> resetPrivacySettings(String userId) async {
    _privacySettings = _getDefaultPrivacySettings();
    await _savePrivacySettings(userId);
  }

  // Export privacy data (for GDPR compliance)
  Future<Map<String, dynamic>> exportPrivacyData(String userId) async {
    try {
      final privacyDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('settings')
          .get();

      final blockedDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('blocked_users')
          .get();

      return {
        'privacySettings': privacyDoc.exists ? privacyDoc.data() : {},
        'blockedUsers': blockedDoc.exists ? blockedDoc.data() : {},
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error exporting privacy data: $e');
      return {};
    }
  }

  // Delete all privacy data (for account deletion)
  Future<void> deletePrivacyData(String userId) async {
    try {
      final batch = _firestore.batch();

      // Delete privacy settings
      final settingsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('settings');
      batch.delete(settingsRef);

      // Delete blocked users
      final blockedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy')
          .doc('blocked_users');
      batch.delete(blockedRef);

      await batch.commit();
    } catch (e) {
      print('Error deleting privacy data: $e');
    }
  }
}
