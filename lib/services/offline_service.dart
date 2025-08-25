// lib/services/offline_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'auth_service.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  static const String _queuedMessagesKey = 'queued_messages';
  static const String _queuedActionsKey = 'queued_actions';
  static const String _cachedChatsKey = 'cached_chats';
  static const String _cachedUsersKey = 'cached_users';
  static const String _lastSyncKey = 'last_sync_timestamp';

  List<QueuedMessage> _queuedMessages = [];
  List<QueuedAction> _queuedActions = [];
  Map<String, List<Message>> _cachedChats = {};
  Map<String, User> _cachedUsers = {};
  bool _isOnline = true;
  bool _isSyncing = false;

  // Initialize offline service
  Future<void> initialize() async {
    await _loadQueuedData();
    await _loadCachedData();
    _startConnectivityListener();
  }

  // Queue message for offline sending
  Future<void> queueMessage({
    required String recipientId,
    required String content,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final queuedMessage = QueuedMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUser.uid,
      recipientId: recipientId,
      content: content,
      timestamp: DateTime.now(),
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderId: replyToSenderId,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      attempts: 0,
      maxAttempts: 3,
    );

    _queuedMessages.add(queuedMessage);
    await _saveQueuedMessages();

    // Try to send immediately if online
    if (_isOnline) {
      _processQueuedMessages();
    }
  }

  // Queue action for offline execution
  Future<void> queueAction({
    required String actionType,
    required Map<String, dynamic> actionData,
  }) async {
    final queuedAction = QueuedAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      actionType: actionType,
      actionData: actionData,
      timestamp: DateTime.now(),
      attempts: 0,
      maxAttempts: 3,
    );

    _queuedActions.add(queuedAction);
    await _saveQueuedActions();

    // Try to execute immediately if online
    if (_isOnline) {
      _processQueuedActions();
    }
  }

  // Cache chat messages for offline viewing
  Future<void> cacheMessages(String chatId, List<Message> messages) async {
    _cachedChats[chatId] = messages;
    await _saveCachedChats();
  }

  // Cache user data for offline viewing
  Future<void> cacheUser(User user) async {
    _cachedUsers[user.uid] = user;
    await _saveCachedUsers();
  }

  // Get cached messages for a chat
  List<Message>? getCachedMessages(String chatId) {
    return _cachedChats[chatId];
  }

  // Get cached user data
  User? getCachedUser(String userId) {
    return _cachedUsers[userId];
  }

  // Process queued messages when online
  Future<void> _processQueuedMessages() async {
    if (_isSyncing || _queuedMessages.isEmpty) return;

    _isSyncing = true;
    final messagesToRemove = <QueuedMessage>[];

    for (final queuedMessage in _queuedMessages) {
      try {
        // Attempt to send the message
        await _databaseService.sendMessage(
          queuedMessage.senderId,
          queuedMessage.recipientId,
          queuedMessage.content,
          replyToMessageId: queuedMessage.replyToMessageId,
          replyToContent: queuedMessage.replyToContent,
          replyToSenderId: queuedMessage.replyToSenderId,
        );

        // If successful, mark for removal
        messagesToRemove.add(queuedMessage);
        print('Successfully sent queued message: ${queuedMessage.id}');
      } catch (e) {
        // Increment attempt count
        queuedMessage.attempts++;

        if (queuedMessage.attempts >= queuedMessage.maxAttempts) {
          // Max attempts reached, remove from queue
          messagesToRemove.add(queuedMessage);
          print('Max attempts reached for message: ${queuedMessage.id}');
        } else {
          print(
              'Failed to send message (attempt ${queuedMessage.attempts}): $e');
        }
      }
    }

    // Remove processed messages
    for (final message in messagesToRemove) {
      _queuedMessages.remove(message);
    }

    await _saveQueuedMessages();
    _isSyncing = false;
  }

  // Process queued actions when online
  Future<void> _processQueuedActions() async {
    if (_isSyncing || _queuedActions.isEmpty) return;

    final actionsToRemove = <QueuedAction>[];

    for (final action in _queuedActions) {
      try {
        await _executeAction(action);
        actionsToRemove.add(action);
        print('Successfully executed queued action: ${action.actionType}');
      } catch (e) {
        action.attempts++;

        if (action.attempts >= action.maxAttempts) {
          actionsToRemove.add(action);
          print('Max attempts reached for action: ${action.actionType}');
        } else {
          print('Failed to execute action (attempt ${action.attempts}): $e');
        }
      }
    }

    // Remove processed actions
    for (final action in actionsToRemove) {
      _queuedActions.remove(action);
    }

    await _saveQueuedActions();
  }

  // Execute a queued action
  Future<void> _executeAction(QueuedAction action) async {
    switch (action.actionType) {
      case 'mark_messages_read':
        final chatId = action.actionData['chatId'] as String;
        final userId = action.actionData['userId'] as String;
        await _databaseService.markMessagesAsRead(chatId, userId);
        break;
      case 'update_typing_status':
        final currentUserId = action.actionData['currentUserId'] as String;
        final otherUserId = action.actionData['otherUserId'] as String;
        final isTyping = action.actionData['isTyping'] as bool;
        await _databaseService.setTypingStatus(
            currentUserId, otherUserId, isTyping);
        break;
      case 'delete_message':
        final user1Id = action.actionData['user1Id'] as String;
        final user2Id = action.actionData['user2Id'] as String;
        final messageId = action.actionData['messageId'] as String;
        await _databaseService.deleteMessage(user1Id, user2Id, messageId);
        break;
      default:
        print('Unknown action type: ${action.actionType}');
    }
  }

  // Connectivity status management
  void setOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;

      if (isOnline) {
        print('Connection restored - processing queued items');
        _processQueuedMessages();
        _processQueuedActions();
      } else {
        print('Connection lost - entering offline mode');
      }
    }
  }

  // Start listening for connectivity changes
  void _startConnectivityListener() {
    // In a real implementation, you would use connectivity_plus package
    // For now, we'll assume online status
    _isOnline = true;
  }

  // Save/Load queued data
  Future<void> _saveQueuedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = _queuedMessages.map((msg) => msg.toJson()).toList();
    await prefs.setString(_queuedMessagesKey, jsonEncode(jsonData));
  }

  Future<void> _saveQueuedActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = _queuedActions.map((action) => action.toJson()).toList();
    await prefs.setString(_queuedActionsKey, jsonEncode(jsonData));
  }
  Future<void> _saveCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = <String, dynamic>{};

    _cachedChats.forEach((chatId, messages) {
      jsonData[chatId] = messages.map((msg) => msg.toMap()).toList();
    });

    await prefs.setString(_cachedChatsKey, jsonEncode(jsonData));
  }

  Future<void> _saveCachedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = <String, dynamic>{};

    _cachedUsers.forEach((userId, user) {
      jsonData[userId] = user.toMap();
    });

    await prefs.setString(_cachedUsersKey, jsonEncode(jsonData));
  }

  Future<void> _loadQueuedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load queued messages
    final messagesJson = prefs.getString(_queuedMessagesKey);
    if (messagesJson != null) {
      final List<dynamic> messagesList = jsonDecode(messagesJson);
      _queuedMessages =
          messagesList.map((json) => QueuedMessage.fromJson(json)).toList();
    }

    // Load queued actions
    final actionsJson = prefs.getString(_queuedActionsKey);
    if (actionsJson != null) {
      final List<dynamic> actionsList = jsonDecode(actionsJson);
      _queuedActions =
          actionsList.map((json) => QueuedAction.fromJson(json)).toList();
    }
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load cached chats
    final chatsJson = prefs.getString(_cachedChatsKey);
    if (chatsJson != null) {
      final Map<String, dynamic> chatsData = jsonDecode(chatsJson);
      _cachedChats.clear();

      chatsData.forEach((chatId, messagesList) {
        final messages = (messagesList as List<dynamic>)
            .map((msgJson) => Message.fromMap(msgJson))
            .toList();
        _cachedChats[chatId] = messages;
      });
    }

    // Load cached users
    final usersJson = prefs.getString(_cachedUsersKey);
    if (usersJson != null) {
      final Map<String, dynamic> usersData = jsonDecode(usersJson);
      _cachedUsers.clear();

      usersData.forEach((userId, userJson) {
        _cachedUsers[userId] = User.fromMap(userJson, uid: userId);
      });
    }
  }

  // Clear all cached data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedChatsKey);
    await prefs.remove(_cachedUsersKey);
    await prefs.remove(_lastSyncKey);

    _cachedChats.clear();
    _cachedUsers.clear();
  }

  // Get offline status and queue info
  Map<String, dynamic> getOfflineStatus() {
    return {
      'isOnline': _isOnline,
      'queuedMessages': _queuedMessages.length,
      'queuedActions': _queuedActions.length,
      'cachedChats': _cachedChats.length,
      'cachedUsers': _cachedUsers.length,
      'isSyncing': _isSyncing,
    };
  }
}

// Queued message model
class QueuedMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime timestamp;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderId;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;
  int attempts;
  final int maxAttempts;

  QueuedMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderId,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    this.attempts = 0,
    this.maxAttempts = 3,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'replyToMessageId': replyToMessageId,
      'replyToContent': replyToContent,
      'replyToSenderId': replyToSenderId,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'attempts': attempts,
      'maxAttempts': maxAttempts,
    };
  }

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'],
      senderId: json['senderId'],
      recipientId: json['recipientId'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      replyToMessageId: json['replyToMessageId'],
      replyToContent: json['replyToContent'],
      replyToSenderId: json['replyToSenderId'],
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      audioDuration: json['audioDuration'],
      attempts: json['attempts'] ?? 0,
      maxAttempts: json['maxAttempts'] ?? 3,
    );
  }
}

// Queued action model
class QueuedAction {
  final String id;
  final String actionType;
  final Map<String, dynamic> actionData;
  final DateTime timestamp;
  int attempts;
  final int maxAttempts;

  QueuedAction({
    required this.id,
    required this.actionType,
    required this.actionData,
    required this.timestamp,
    this.attempts = 0,
    this.maxAttempts = 3,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actionType': actionType,
      'actionData': actionData,
      'timestamp': timestamp.toIso8601String(),
      'attempts': attempts,
      'maxAttempts': maxAttempts,
    };
  }

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'],
      actionType: json['actionType'],
      actionData: Map<String, dynamic>.from(json['actionData']),
      timestamp: DateTime.parse(json['timestamp']),
      attempts: json['attempts'] ?? 0,
      maxAttempts: json['maxAttempts'] ?? 3,
    );
  }
}
