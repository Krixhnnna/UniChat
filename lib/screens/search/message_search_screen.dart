// lib/screens/search/message_search_screen.dart
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/optimized_profile_picture.dart';
import '../../theme/app_fonts.dart';
import 'package:intl/intl.dart';

class MessageSearchScreen extends StatefulWidget {
  final String? chatId;
  final User? otherUser;

  const MessageSearchScreen({
    Key? key,
    this.chatId,
    this.otherUser,
  }) : super(key: key);

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  final AuthService _authService = AuthService();

  List<SearchResult> _searchResults = [];
  List<String> _searchSuggestions = [];
  bool _isSearching = false;
  bool _showFilters = false;
  SearchFilters _filters = const SearchFilters();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;
    _loadSearchSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSearchSuggestions() async {
    if (_currentUserId != null) {
      final suggestions = await _searchService.getSearchSuggestions(
        userId: _currentUserId!,
      );
      setState(() {
        _searchSuggestions = suggestions;
      });
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<SearchResult> results;

      if (widget.chatId != null) {
        // Search in specific chat
        final messages = await _searchService.searchMessagesInChat(
          chatId: widget.chatId!,
          query: query,
        );
        results = messages
            .map((message) => SearchResult(
                  message: message,
                  chatId: widget.chatId!,
                  otherUserId: widget.otherUser?.uid ?? '',
                  matchedText: message.content,
                ))
            .toList();
      } else {
        // Search across all chats
        results = await _searchService.advancedMessageSearch(
          userId: _currentUserId!,
          query: query,
          fromUserId: _filters.fromUserId,
          startDate: _filters.startDate,
          endDate: _filters.endDate,
          hasImages: _filters.hasImages,
          hasAudio: _filters.hasAudio,
        );
      }

      setState(() {
        _searchResults = results;
      });

      // Save search query for suggestions
      await _searchService.saveSearchQuery(_currentUserId!, query);
    } catch (e) {
      print('Error performing search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => SearchFiltersDialog(
        filters: _filters,
        onFiltersChanged: (newFilters) {
          setState(() {
            _filters = newFilters;
          });
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.chatId != null
                ? 'Search in this chat...'
                : 'Search messages...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          onChanged: _performSearch,
          autofocus: true,
        ),
        actions: [
          if (widget.chatId == null)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white),
                  if (_hasActiveFilters())
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _showFilterDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            const LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_searchController.text.isEmpty) {
      return _buildSearchSuggestions();
    }

    if (_searchResults.isEmpty && !_isSearching) {
      return _buildNoResults();
    }

    return _buildSearchResults();
  }

  Widget _buildSearchSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recent Searches',
            style: AppFonts.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _searchSuggestions[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(
                  suggestion,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _searchController.text = suggestion;
                  _performSearch(suggestion);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.call_made, color: Colors.grey),
                  onPressed: () {
                    _searchController.text = suggestion;
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or adjust filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return SearchResultTile(
          result: result,
          searchQuery: _searchController.text,
          onTap: () {
            // Navigate to chat at specific message
            Navigator.pop(context, {
              'chatId': result.chatId,
              'messageId': result.message.id,
              'otherUserId': result.otherUserId,
            });
          },
        );
      },
    );
  }

  bool _hasActiveFilters() {
    return _filters.fromUserId != null ||
        _filters.startDate != null ||
        _filters.endDate != null ||
        _filters.hasImages != null ||
        _filters.hasAudio != null;
  }
}

class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final String searchQuery;
  final VoidCallback onTap;

  const SearchResultTile({
    Key? key,
    required this.result,
    required this.searchQuery,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final message = result.message;
    final isOwnMessage = message.senderId == AuthService().currentUser?.uid;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile picture placeholder
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isOwnMessage ? const Color(0xFF8B5CF6) : Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOwnMessage ? Icons.send : Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender and timestamp
                  Row(
                    children: [
                      Text(
                        isOwnMessage ? 'You' : 'Other User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, HH:mm').format(message.timestamp),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Message content with highlighting
                  RichText(
                    text: _buildHighlightedText(
                      result.matchedText,
                      searchQuery,
                    ),
                  ),

                  // Media indicators
                  if (message.imageUrl != null || message.audioUrl != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (message.imageUrl != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '📷 Image',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (message.audioUrl != null) ...[
                          if (message.imageUrl != null)
                            const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '🎵 Audio',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white70),
      );
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    int index = textLower.indexOf(queryLower, start);

    while (index != -1) {
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(color: Colors.white70),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          color: Color(0xFF8B5CF6),
          backgroundColor: Color(0xFF8B5CF6),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = textLower.indexOf(queryLower, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: const TextStyle(color: Colors.white70),
      ));
    }

    return TextSpan(children: spans);
  }
}

class SearchFiltersDialog extends StatefulWidget {
  final SearchFilters filters;
  final Function(SearchFilters) onFiltersChanged;

  const SearchFiltersDialog({
    Key? key,
    required this.filters,
    required this.onFiltersChanged,
  }) : super(key: key);

  @override
  State<SearchFiltersDialog> createState() => _SearchFiltersDialogState();
}

class _SearchFiltersDialogState extends State<SearchFiltersDialog> {
  late SearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text(
        'Search Filters',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range
            const Text(
              'Date Range',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filters.startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _filters = _filters.copyWith(startDate: date);
                        });
                      }
                    },
                    child: Text(
                      _filters.startDate != null
                          ? DateFormat('MMM d, yyyy')
                              .format(_filters.startDate!)
                          : 'Start Date',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const Text('-', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filters.endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _filters = _filters.copyWith(endDate: date);
                        });
                      }
                    },
                    child: Text(
                      _filters.endDate != null
                          ? DateFormat('MMM d, yyyy').format(_filters.endDate!)
                          : 'End Date',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Media filters
            const Text(
              'Message Type',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            CheckboxListTile(
              title: const Text('Has Images',
                  style: TextStyle(color: Colors.white70)),
              value: _filters.hasImages,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  _filters = _filters.copyWith(hasImages: value);
                });
              },
              activeColor: const Color(0xFF8B5CF6),
            ),
            CheckboxListTile(
              title: const Text('Has Audio',
                  style: TextStyle(color: Colors.white70)),
              value: _filters.hasAudio,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  _filters = _filters.copyWith(hasAudio: value);
                });
              },
              activeColor: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _filters = const SearchFilters();
            });
          },
          child: const Text(
            'Clear',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFiltersChanged(_filters);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
