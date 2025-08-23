// lib/services/search_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'dart:math' as math;

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search messages in a specific chat
  Future<List<Message>> searchMessagesInChat({
    required String chatId,
    required String query,
    int limit = 50,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      final queryLower = query.toLowerCase().trim();

      // Search in messages content
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(500) // Limit for performance
          .get();

      final results = <Message>[];

      for (final doc in messagesSnapshot.docs) {
        final message = Message.fromMap(doc.data(), id: doc.id);

        // Check if message content contains the query
        if (message.content.toLowerCase().contains(queryLower)) {
          results.add(message);
          if (results.length >= limit) break;
        }
      }

      return results;
    } catch (e) {
      print('Error searching messages in chat: $e');
      return [];
    }
  }

  // Search messages across all chats for a user
  Future<List<SearchResult>> searchAllMessages({
    required String userId,
    required String query,
    int limit = 100,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      final results = <SearchResult>[];
      final queryLower = query.toLowerCase().trim();

      // Get all chats for the user
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      // Search in each chat
      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final chatData = chatDoc.data();

        // Get other participant info for context
        final participants = List<String>.from(chatData['participants'] ?? []);
        final otherUserId =
            participants.firstWhere((id) => id != userId, orElse: () => '');

        // Search messages in this chat
        final messages = await searchMessagesInChat(
          chatId: chatId,
          query: query,
          limit: 10, // Limit per chat
        );

        // Add results with chat context
        for (final message in messages) {
          results.add(SearchResult(
            message: message,
            chatId: chatId,
            otherUserId: otherUserId,
            matchedText: _extractMatchedText(message.content, queryLower),
          ));

          if (results.length >= limit) break;
        }

        if (results.length >= limit) break;
      }

      // Sort by relevance and timestamp
      results
          .sort((a, b) => b.message.timestamp.compareTo(a.message.timestamp));

      return results.take(limit).toList();
    } catch (e) {
      print('Error searching all messages: $e');
      return [];
    }
  }

  // Search users by name, email, or other fields
  Future<List<User>> searchUsers({
    required String query,
    String? excludeUserId,
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      final queryLower = query.toLowerCase().trim();
      final results = <User>[];

      // Search by display name (partial match)
      final nameQuery = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: queryLower)
          .where('displayNameLower', isLessThan: queryLower + 'z')
          .limit(limit)
          .get();

      for (final doc in nameQuery.docs) {
        if (excludeUserId != null && doc.id == excludeUserId) continue;
        results.add(User.fromMap(doc.data(), uid: doc.id));
      }

      // Search by email if query looks like an email
      if (query.contains('@') && results.length < limit) {
        final emailQuery = await _firestore
            .collection('users')
            .where('emailLower', isGreaterThanOrEqualTo: queryLower)
            .where('emailLower', isLessThan: queryLower + 'z')
            .limit(limit - results.length)
            .get();

        for (final doc in emailQuery.docs) {
          if (excludeUserId != null && doc.id == excludeUserId) continue;
          if (!results.any((user) => user.uid == doc.id)) {
            results.add(User.fromMap(doc.data(), uid: doc.id));
          }
        }
      }

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Search with advanced filters
  Future<List<SearchResult>> advancedMessageSearch({
    required String userId,
    required String query,
    String? fromUserId,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasImages,
    bool? hasAudio,
    int limit = 50,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      final results = <SearchResult>[];
      final queryLower = query.toLowerCase().trim();

      // Get all chats for the user
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);
        final otherUserId =
            participants.firstWhere((id) => id != userId, orElse: () => '');

        // Skip if fromUserId filter doesn't match
        if (fromUserId != null && otherUserId != fromUserId) continue;

        // Build Firestore query with filters
        Query messagesQuery = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true);

        // Apply date filters
        if (startDate != null) {
          messagesQuery = messagesQuery.where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          messagesQuery = messagesQuery.where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }

        final messagesSnapshot = await messagesQuery.limit(200).get();

        for (final doc in messagesSnapshot.docs) {
          final message =
              Message.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);

          // Apply content filter
          if (!message.content.toLowerCase().contains(queryLower)) continue;

          // Apply media filters
          if (hasImages == true && message.imageUrl == null) continue;
          if (hasImages == false && message.imageUrl != null) continue;
          if (hasAudio == true && message.audioUrl == null) continue;
          if (hasAudio == false && message.audioUrl != null) continue;

          results.add(SearchResult(
            message: message,
            chatId: chatId,
            otherUserId: otherUserId,
            matchedText: _extractMatchedText(message.content, queryLower),
          ));

          if (results.length >= limit) break;
        }

        if (results.length >= limit) break;
      }

      // Sort by relevance and timestamp
      results
          .sort((a, b) => b.message.timestamp.compareTo(a.message.timestamp));

      return results;
    } catch (e) {
      print('Error in advanced search: $e');
      return [];
    }
  }

  // Extract matched text with context
  String _extractMatchedText(String content, String query) {
    final index = content.toLowerCase().indexOf(query);
    if (index == -1) return content;

    const contextLength = 30;
    final start = math.max(0, index - contextLength);
    final end = math.min(content.length, index + query.length + contextLength);

    String excerpt = content.substring(start, end);

    if (start > 0) excerpt = '...$excerpt';
    if (end < content.length) excerpt = '$excerpt...';

    return excerpt;
  }

  // Get search suggestions based on previous searches
  Future<List<String>> getSearchSuggestions({
    required String userId,
    int limit = 10,
  }) async {
    try {
      // In a real implementation, you would store search history
      // For now, return some common search terms
      return [
        'hello',
        'how are you',
        'good morning',
        'good night',
        'thank you',
        'see you later',
        'call me',
        'meeting',
        'photo',
        'video',
      ];
    } catch (e) {
      print('Error getting search suggestions: $e');
      return [];
    }
  }

  // Save search query for suggestions (placeholder)
  Future<void> saveSearchQuery(String userId, String query) async {
    try {
      // In a real implementation, you would save to user's search history
      print('Saving search query: $query for user: $userId');
    } catch (e) {
      print('Error saving search query: $e');
    }
  }

  // Clear search history
  Future<void> clearSearchHistory(String userId) async {
    try {
      // In a real implementation, you would clear user's search history
      print('Clearing search history for user: $userId');
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }
}

// Search result model
class SearchResult {
  final Message message;
  final String chatId;
  final String otherUserId;
  final String matchedText;

  SearchResult({
    required this.message,
    required this.chatId,
    required this.otherUserId,
    required this.matchedText,
  });
}

// Search filters model
class SearchFilters {
  final String? fromUserId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? hasImages;
  final bool? hasAudio;
  final bool? hasReactions;

  const SearchFilters({
    this.fromUserId,
    this.startDate,
    this.endDate,
    this.hasImages,
    this.hasAudio,
    this.hasReactions,
  });

  SearchFilters copyWith({
    String? fromUserId,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasImages,
    bool? hasAudio,
    bool? hasReactions,
  }) {
    return SearchFilters(
      fromUserId: fromUserId ?? this.fromUserId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      hasImages: hasImages ?? this.hasImages,
      hasAudio: hasAudio ?? this.hasAudio,
      hasReactions: hasReactions ?? this.hasReactions,
    );
  }
}
