import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:campus_crush/models/message_model.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/database_service.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:record/record.dart' as audio_rec;

import 'package:audioplayers/audioplayers.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/verification_badge.dart';
import '../../utils/user_verification.dart';

class ChatScreen extends StatefulWidget {
  final User otherUser;

  const ChatScreen({Key? key, required this.otherUser}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Message> _messages = [];
  List<Message> _optimisticMessages = [];
  bool _isLoading = false;
  String? _currentUserId;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;

  // Multi-select functionality
  bool _isSelectionMode = false;
  Set<String> _selectedMessageIds = {};

  // Reply functionality
  Message? _replyingToMessage;
  bool _isReplying = false;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Drag tracking for swipe gestures
  double? _dragStartX;
  final Map<String, double> _messageOffsets =
      {}; // Track offset for each message

  // Audio recording
  // final audio_rec.Record _recorder = audio_rec.Record();
  bool _isRecording = false;
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  double _recordDragOffset = 0.0;
  double? _recordDragStartX;

  // Audio playback
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Set<String> _playingMessageIds = {};

  // User interaction tracking
  bool _isUserInteracting = false;
  Timer? _interactionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();

    // Add scroll listener to detect user interactions
    _scrollController.addListener(_onScroll);

    // Single scroll to bottom after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
        // Mark messages as read after scrolling
        Timer(const Duration(milliseconds: 500), () {
          if (mounted) _markMessagesAsRead();
        });
      }
    });
  }

  void _initializeChat() async {
    final user = _authService.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUserId = user.uid;
          _isLoading = true; // Set loading to true initially
        });
      }

      // Listen to messages from Firebase
      _databaseService
          .getMessages(_currentUserId!, widget.otherUser.uid)
          .listen((messages) {
        if (mounted) {
          print('DEBUG: Messages stream received ${messages.length} messages');
          if (messages.isNotEmpty) {
            print(
                'DEBUG: First message: "${messages.first.content}" at ${messages.first.timestamp}');
            print(
                'DEBUG: Last message: "${messages.last.content}" at ${messages.last.timestamp}');
          }

          final bool isFirstLoad = _messages.isEmpty && messages.isNotEmpty;
          final bool hasNewMessages = messages.isNotEmpty &&
              (_messages.isEmpty ||
                  messages.first.timestamp.isAfter(_messages.first.timestamp));

          setState(() {
            // Messages come from Firebase in descending order (newest first)
            // But we need to display them in ascending order (oldest first) for chat UI
            _messages = messages.reversed.toList();
            _isLoading = false; // Set loading to false when messages arrive
          });

          // Scroll to bottom only when opening a chat or when new messages arrive
          if (isFirstLoad) {
            print('Chat: First load - scrolling to bottom');
            _scrollToBottom();
          } else if (hasNewMessages) {
            print('Chat: New messages - scrolling to bottom');
            _scrollToBottom();
          }

          // Mark messages as read when new messages arrive (user is viewing the chat)
          if (hasNewMessages) {
            // Check if the new messages are from the other user (not our own messages)
            final newMessagesFromOther = messages
                .where((msg) => msg.senderId != _currentUserId && !msg.isRead)
                .isNotEmpty;

            if (newMessagesFromOther) {
              // Delay to ensure message is properly loaded before marking as read
              Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _markMessagesAsRead();
                }
              });
            }
          }
        }
      });

      // Listen to other user's online status
      _databaseService.getUserDocument(widget.otherUser.uid).listen((data) {
        if (!mounted) return;
        setState(() {
          _isOtherUserOnline = (data?['isOnline'] as bool?) ?? false;

          // Try multiple possible field names for last seen
          var lastSeenTs = data?['lastActive'] ??
              data?['lastSeen'] ??
              data?['lastActiveTime'];

          if (lastSeenTs != null) {
            if (lastSeenTs is Timestamp) {
              _otherUserLastSeen = lastSeenTs.toDate();
            } else if (lastSeenTs is DateTime) {
              _otherUserLastSeen = lastSeenTs;
            }
          } else {
            // If no timestamp found, set to a default time for testing
            _otherUserLastSeen =
                DateTime.now().subtract(const Duration(days: 3));
          }

          print(
              'Debug: isOnline=${_isOtherUserOnline}, lastSeen=${_otherUserLastSeen}, data=$data'); // Debug print
        });
      });
    }
  }

  Future<void> _startRecording() async {
    // TODO: Implement audio recording
    print('Audio recording not implemented yet');
  }

  Future<void> _cancelRecording() async {
    // TODO: Implement audio recording cancellation
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _recordDragOffset = 0;
    });
  }

  Future<void> _stopAndSendRecording() async {
    // TODO: Implement stop and send recording
    setState(() {
      _isRecording = false;
    });

    // Send push notification for audio message
    await _sendPushNotification('🎤 Voice message');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlayAudio(Message message) async {
    final id = message.id;
    final url = message.audioUrl;
    if (url == null) return;

    // Stop others
    for (final mid in _playingMessageIds.toList()) {
      if (mid != id) {
        await _audioPlayers[mid]?.stop();
        await _audioPlayers[mid]?.release();
        _audioPlayers.remove(mid);
        _playingMessageIds.remove(mid);
      }
    }

    if (_playingMessageIds.contains(id)) {
      await _audioPlayers[id]?.stop();
      await _audioPlayers[id]?.release();
      _audioPlayers.remove(id);
      setState(() {
        _playingMessageIds.remove(id);
      });
      return;
    }

    final player = AudioPlayer();
    _audioPlayers[id] = player;
    player.onPlayerComplete.listen((_) {
      setState(() {
        _playingMessageIds.remove(id);
      });
      player.release();
      _audioPlayers.remove(id);
    });
    await player.play(UrlSource(url));
    setState(() {
      _playingMessageIds.add(id);
    });
  }

  void _scrollToBottom() {
    if (!mounted || _isUserInteracting) return;

    // Use a single, gentle scroll approach
    _scrollToBottomGentle();
  }

  void _scrollToBottomGentle() {
    if (mounted && _scrollController.hasClients) {
      try {
        if (_scrollController.position.maxScrollExtent > 0) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          print('Gentle scroll to bottom');
        }
      } catch (e) {
        print('Scroll error: $e');
        // Fallback to jump if animation fails
        try {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } catch (e2) {
          print('Fallback scroll error: $e2');
        }
      }
    }
  }

  // Track user interactions to prevent unwanted scrolling
  void _onUserInteraction() {
    _isUserInteracting = true;
    _interactionTimer?.cancel();
    _interactionTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
      }
    });
  }

  // Detect when user manually scrolls
  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      // If user is not at the bottom, they're manually scrolling
      if (position.pixels < position.maxScrollExtent - 10) {
        _onUserInteraction();
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();
    print('Sending message: "$messageContent"');

    _messageController.clear();

    if (_currentUserId != null) {
      // Create optimistic message with current timestamp
      final optimisticMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: _currentUserId!,
        content: messageContent,
        timestamp: DateTime.now(),
        isRead: false,
        replyToMessageId: _replyingToMessage?.id,
        replyToContent: _replyingToMessage?.content,
        replyToSenderId: _replyingToMessage?.senderId,
      );

      if (mounted) {
        setState(() {
          _optimisticMessages
              .add(optimisticMessage); // Add to end instead of beginning
        });
      }

      // Scroll to bottom after adding optimistic message (only if not interacting)
      if (!_isUserInteracting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }

      try {
        await _databaseService.sendMessage(
          _currentUserId!,
          widget.otherUser.uid,
          messageContent,
          replyToMessageId: _replyingToMessage?.id,
          replyToContent: _replyingToMessage?.content,
          replyToSenderId: _replyingToMessage?.senderId,
        );

        // Remove optimistic message after successful send
        if (mounted) {
          setState(() {
            _optimisticMessages
                .removeWhere((msg) => msg.id == optimisticMessage.id);
          });
          print('Message sent successfully');
        }

        // Send push notification to the other user
        await _sendPushNotification(messageContent);

        // Clear reply state after sending
        _cancelReply();
      } catch (e) {
        print('Error sending message: $e');
        // Remove optimistic message on error
        if (mounted) {
          setState(() {
            _optimisticMessages
                .removeWhere((msg) => msg.id == optimisticMessage.id);
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _sendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null && _currentUserId != null) {
        // Create optimistic message
        final optimisticMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: _currentUserId!,
          content: '',
          timestamp: DateTime.now(),
          isRead: false,
          imageUrl: image.path, // Temporary local path
        );

        setState(() {
          _optimisticMessages
              .add(optimisticMessage); // Add to end instead of beginning
        });

        // Scroll to bottom after adding optimistic image message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        // TODO: Implement actual image upload to Firebase Storage
        // For now, just simulate upload delay
        await Future.delayed(const Duration(seconds: 2));

        // Send push notification for image
        await _sendPushNotification('📷 Image');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _onMessageTap(Message message) {
    // Show message options (edit, delete, etc.)
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildMessageOptions(message),
    );
  }

  Widget _buildMessageOptions(Message message) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.senderId == _currentUserId) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(message);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement reply functionality
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(Message message) {
    final TextEditingController editController =
        TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your message',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: _safePop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                try {
                  await _databaseService.editMessage(
                    _currentUserId!,
                    widget.otherUser.uid,
                    message.id,
                    editController.text.trim(),
                  );
                  _safePop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit message: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: _safePop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _safePop();
              try {
                await _databaseService.deleteMessage(
                  _currentUserId!,
                  widget.otherUser.uid,
                  message.id,
                );
                // Remove from local list
                if (mounted) {
                  setState(() {
                    _messages.removeWhere((msg) => msg.id == message.id);
                  });
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete message: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Multi-select functionality
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMessageIds.clear();
      }
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }

      // Exit selection mode if no messages are selected
      if (_selectedMessageIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: Text(
            'Are you sure you want to delete ${_selectedMessageIds.length} selected message${_selectedMessageIds.length > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: _safePop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _safePop();
              try {
                // Delete all selected messages
                for (String messageId in _selectedMessageIds) {
                  await _databaseService.deleteMessage(
                    _currentUserId!,
                    widget.otherUser.uid,
                    messageId,
                  );
                }

                // Remove from local list
                if (mounted) {
                  setState(() {
                    _messages.removeWhere(
                        (msg) => _selectedMessageIds.contains(msg.id));
                    _selectedMessageIds.clear();
                    _isSelectionMode = false;
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Deleted ${_selectedMessageIds.length} message${_selectedMessageIds.length > 1 ? 's' : ''}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete messages: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _startReply(Message message) {
    setState(() {
      _replyingToMessage = message;
      _isReplying = true;
    });
    _messageController.clear();
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
      _isReplying = false;
    });
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  String _formatDate(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDate == today) return 'Today';
    if (messageDate == today.subtract(const Duration(days: 1)))
      return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(timestamp);
  }

  String _presenceText() {
    if (_isTyping) return 'typing...';
    if (_isOtherUserOnline) return 'online';
    if (_otherUserLastSeen != null) {
      final now = DateTime.now();
      final lastSeen = _otherUserLastSeen!;
      final diff = now.difference(lastSeen);

      // If last seen today, show relative time
      if (lastSeen.year == now.year &&
          lastSeen.month == now.month &&
          lastSeen.day == now.day) {
        if (diff.inMinutes < 1) {
          return 'Last seen just now';
        } else if (diff.inMinutes < 60) {
          return 'Last seen ${diff.inMinutes} min ago';
        } else {
          return 'Last seen ${diff.inHours} hr ago';
        }
      }

      // If last seen yesterday
      if (diff.inDays == 1) {
        return 'Last seen yesterday';
      }

      // If last seen 2-7 days ago
      if (diff.inDays >= 2 && diff.inDays < 7) {
        return 'Last seen a few days ago';
      }

      // If last seen more than a week ago
      if (diff.inDays >= 7) {
        final weeks = (diff.inDays / 7).floor();
        if (weeks == 1) {
          return 'Last seen a week ago';
        } else if (weeks < 4) {
          return 'Last seen ${weeks} weeks ago';
        } else {
          final months = (diff.inDays / 30).floor();
          if (months == 1) {
            return 'Last seen a month ago';
          } else {
            return 'Last seen a long time ago';
          }
        }
      }
    }
    return 'Last seen a long time ago';
  }

  String _getDisplayNameInitial() {
    final displayName = widget.otherUser.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return 'U';
  }

  String _getReplyPreviewText() {
    final replyMessage = _replyingToMessage;
    if (replyMessage == null) return '';
    return replyMessage.content.isNotEmpty ? replyMessage.content : 'Image';
  }

  String _getReplyPreviewSender() {
    final replyMessage = _replyingToMessage;
    final userId = _currentUserId;
    if (replyMessage == null || userId == null) return 'Unknown';
    return replyMessage.senderId == userId
        ? 'You'
        : widget.otherUser.displayName ?? 'Unknown';
  }

  Color _getStatusColor() {
    if (_isTyping) {
      return Colors.purple; // Typing indicator
    }
    if (_isOtherUserOnline) {
      return Colors.green; // Online
    }
    if (_otherUserLastSeen != null) {
      final now = DateTime.now();
      final lastSeen = _otherUserLastSeen!;
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 30) {
        return Colors.yellow; // Recently online (under 30 minutes)
      }
    }
    return Colors.grey; // Offline
  }

  // Track if read operation is in progress to prevent multiple calls
  bool _isMarkingAsRead = false;
  Timer? _markAsReadTimer;

  // Mark messages as read when viewing the chat (with debouncing)
  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;

    // Cancel any pending mark-as-read operation
    _markAsReadTimer?.cancel();

    // Debounce the mark-as-read operation
    _markAsReadTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isMarkingAsRead || !mounted) return;

      _isMarkingAsRead = true;

      try {
        final List<String> userIds = [_currentUserId!, widget.otherUser.uid]
          ..sort();
        final String chatId = userIds.join('_');

        // Use the database service method which handles transactions properly
        await _databaseService.markMessagesAsRead(chatId, _currentUserId!);

        print('Messages marked as read for chat: $chatId');
      } catch (e) {
        print('Error marking messages as read: $e');
      } finally {
        _isMarkingAsRead = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while user is being initialized
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        titleSpacing: 0,
        leading: IconButton(
          icon: SvgPicture.string(
            '''<svg fill="#000000" version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100.00 100.00" enable-background="new 0 0 100 100" xml:space="preserve" stroke="#000000" stroke-width="5.1"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <g> <path d="M33.934,54.458l30.822,27.938c0.383,0.348,0.864,0.519,1.344,0.519c0.545,0,1.087-0.222,1.482-0.657 c0.741-0.818,0.68-2.083-0.139-2.824L37.801,52.564L64.67,22.921c0.742-0.818,0.68-2.083-0.139-2.824 c-0.817-0.742-2.082-0.679-2.824,0.139L33.768,51.059c-0.439,0.485-0.59,1.126-0.475,1.723 C33.234,53.39,33.446,54.017,33.934,54.458z"></path> </g> </g></svg>''',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: _safePop,
          padding: const EdgeInsets.only(left: 8, right: 0),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22, // Exact size from screenshot
                  backgroundImage: widget.otherUser.profilePhotos.isNotEmpty
                      ? NetworkImage(widget.otherUser.profilePhotos[0])
                      : null,
                  child: widget.otherUser.profilePhotos.isEmpty
                      ? Text(
                          _getDisplayNameInitial(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                // Status indicator overlay on profile picture
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isSelectionMode
                            ? '${_selectedMessageIds.length} selected'
                            : widget.otherUser.displayName ?? 'Unknown User',
                        style: AppFonts.titleMedium.copyWith(
                          color: Colors.white,
                          fontSize: 16, // Smaller font size for person's name
                        ),
                      ),
                      if (!_isSelectionMode) ...[
                        const SizedBox(width: 6),
                        VerificationBadge(
                          isVerified: true, // Temporarily hardcoded for testing
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  if (!_isSelectionMode)
                    Text(
                      _presenceText(),
                      style: AppFonts.caption.copyWith(
                        color: const Color(
                            0xFF8E8E93), // Exact color from screenshot
                        fontSize: 11, // Smaller font size for status
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _toggleSelectionMode,
            ),
            if (_selectedMessageIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelectedMessages,
              ),
          ] else ...[
            IconButton(
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons
                        .alternate_email, // Using alternate_email icon as closest match
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              onPressed: () {
                // TODO: Implement mention functionality
              },
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
              onPressed: () {
                // TODO: Show more options
              },
              padding: const EdgeInsets.all(8),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildChatContent(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    // Show loading state while initially loading (with minimum duration to prevent flash)
    if (_isLoading && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF895BE0),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Show messages if we have any
    if (_messages.isNotEmpty) {
      return _buildMessagesList();
    }

    // Only show empty state if we're not loading and truly have no messages
    if (!_isLoading && _messages.isEmpty) {
      return _buildEmptyState();
    }

    // Fallback loading state
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF895BE0),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with ${widget.otherUser.displayName ?? 'your match'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    // Filter out optimistic messages that have been confirmed in Firebase
    final confirmedMessageIds = _messages.map((msg) => msg.id).toSet();
    final pendingOptimisticMessages = _optimisticMessages
        .where((msg) => !confirmedMessageIds.contains(msg.id))
        .toList();

    // Combine messages in correct order: _messages (old to new) + optimistic messages (newest)
    final allMessages = [..._messages, ...pendingOptimisticMessages];

    // Ensure scroll to bottom after building messages list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && allMessages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    // Group messages by date using DateTime keys (midnight)
    final Map<DateTime, List<Message>> groupedByDate = {};
    for (final message in allMessages) {
      final dayKey = DateTime(message.timestamp.year, message.timestamp.month,
          message.timestamp.day);
      groupedByDate.putIfAbsent(dayKey, () => []);
      final dayMessages = groupedByDate[dayKey];
      if (dayMessages != null) {
        dayMessages.add(message);
      }
    }
    final dateKeys = groupedByDate.keys.toList()..sort();

    // Sort messages within each date group (oldest first)
    for (final key in groupedByDate.keys) {
      final messages = groupedByDate[key];
      if (messages != null) {
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse:
          false, // Changed from true to false - older messages at top, newer at bottom
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: dateKeys.length * 2,
      itemBuilder: (context, index) {
        final dateIndex = index ~/ 2;
        final isDateSeparator = index % 2 == 0;
        final dateKey = dateKeys[dateIndex];
        final date = _formatDate(dateKey);

        if (isDateSeparator) {
          // Date separator - EXACT styling from screenshot
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E), // Exact grey from screenshot
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    color:
                        Color(0xFF8E8E93), // Exact text color from screenshot
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        } else {
          // Messages for this date
          final messages = groupedByDate[dateKey];
          if (messages == null) return const SizedBox.shrink();
          return Column(
            children: messages.map((message) {
              final isOwnMessage =
                  _currentUserId != null && message.senderId == _currentUserId;
              final isSelected = _selectedMessageIds.contains(message.id);
              final isDeleted = message.content == 'This message was deleted';

              return Stack(
                children: [
                  // Background Reply indicator - show only on the swiped side
                  if ((_messageOffsets[message.id] ?? 0).abs() > 4)
                    Positioned(
                      top: 0,
                      bottom: 12,
                      left: isOwnMessage ? null : 0,
                      right: isOwnMessage ? 0 : null,
                      width: 72, // Visual reveal width like popular chat apps
                      child: Container(
                        alignment: isOwnMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.reply,
                          color: const Color(0xFF8B5CF6),
                          size: 22,
                        ),
                      ),
                    ),
                  // Transform the message with limited movement
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(
                        _messageOffsets[message.id] ?? 0, 0, 0),
                    child: GestureDetector(
                      onHorizontalDragStart: (details) {
                        _dragStartX = details.globalPosition.dx;
                        _onUserInteraction();
                      },
                      onHorizontalDragUpdate: (details) {
                        if (_dragStartX == null) return;

                        final currentX = details.globalPosition.dx;
                        final rawOffset = currentX - _dragStartX!;
                        // Cap the visual movement, independent of trigger thresholds
                        const maxVisualOffset = 72.0; // ~reply affordance width

                        // Check if swipe is in correct direction
                        final isValidDirection =
                            (isOwnMessage && rawOffset < 0) || // Left for own
                                (!isOwnMessage &&
                                    rawOffset > 0); // Right for others

                        if (isValidDirection) {
                          // Limit the offset to maximum distance
                          final clampedOffset =
                              rawOffset.abs() > maxVisualOffset
                                  ? (rawOffset > 0
                                      ? maxVisualOffset
                                      : -maxVisualOffset)
                                  : rawOffset;

                          setState(() {
                            _messageOffsets[message.id] = clampedOffset;
                          });
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        // Decide based on velocity or distance at end of gesture
                        final velocityX = details.primaryVelocity ?? 0.0;
                        final endOffset =
                            (_messageOffsets[message.id] ?? 0).abs();
                        const distanceThreshold =
                            42.0; // Must reveal most of the icon
                        const velocityThreshold = 900.0; // Fast fling

                        final shouldTrigger = endOffset >= distanceThreshold ||
                            velocityX.abs() >= velocityThreshold;

                        if (shouldTrigger) {
                          _startReply(message);
                        }

                        // Snap back to original position
                        setState(() {
                          _messageOffsets[message.id] = 0;
                        });
                        _dragStartX = null;
                      },
                      child: GestureDetector(
                        onTap: _isSelectionMode
                            ? () => _toggleMessageSelection(message.id)
                            : () => _onMessageTap(message),
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode();
                            _toggleMessageSelection(message.id);
                          }
                          _onUserInteraction();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(
                              bottom: 12), // Reduced from 16 to 12
                          child: Row(
                            mainAxisAlignment: isOwnMessage
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_isSelectionMode) ...[
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) =>
                                      _toggleMessageSelection(message.id),
                                  activeColor: Colors.purple,
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (!isOwnMessage) ...[
                                // Profile picture for received messages (left side)
                                CircleAvatar(
                                  radius: 16, // Exact size from screenshot
                                  backgroundImage:
                                      widget.otherUser.profilePhotos.isNotEmpty
                                          ? NetworkImage(
                                              widget.otherUser.profilePhotos[0])
                                          : null,
                                  child: widget.otherUser.profilePhotos.isEmpty
                                      ? Text(
                                          _getDisplayNameInitial(),
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth:
                                        280, // Maximum width to prevent overflow
                                    minWidth: 0, // Allow shrinking to content
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal:
                                        8, // Much smaller horizontal padding
                                    vertical:
                                        6, // Much smaller vertical padding
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOwnMessage
                                        ? const Color(
                                            0xFF8B5CF6) // Purple for sent messages (exact from screenshot)
                                        : const Color(
                                            0xFF1C1C1E), // Dark gray for received messages (exact from screenshot)
                                    borderRadius: BorderRadius.circular(20),
                                    border: isDeleted
                                        ? Border.all(
                                            color: const Color(0xFF8E8E93),
                                            style: BorderStyle.solid,
                                            width: 1)
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Reply preview if this message is a reply
                                      if (message.replyToMessageId != null) ...[
                                        Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _currentUserId != null &&
                                                            message.replyToSenderId ==
                                                                _currentUserId
                                                        ? 'You'
                                                        : widget.otherUser
                                                                .displayName ??
                                                            'Unknown',
                                                    style: const TextStyle(
                                                      color: Color(0xFF8B5CF6),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (_currentUserId != null &&
                                                      message.replyToSenderId !=
                                                          _currentUserId) ...[
                                                    const SizedBox(width: 4),
                                                    VerificationBadge(
                                                      isVerified: UserVerification
                                                          .getDisplayVerificationStatus(
                                                              widget.otherUser),
                                                      size: 10,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                message.replyToContent ??
                                                    'Image',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (message.imageUrl != null) ...[
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            File(message.imageUrl!),
                                            width: 200,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        if (message.content.isNotEmpty)
                                          const SizedBox(height: 8),
                                      ],
                                      if (message.audioUrl != null) ...[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _togglePlayAudio(message),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _playingMessageIds
                                                          .contains(message.id)
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _formatDuration(Duration(
                                                  milliseconds:
                                                      message.audioDurationMs ??
                                                          0)),
                                              style: const TextStyle(
                                                  color: Colors.white70),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatTime(message.timestamp),
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 200, 200, 200),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (message.content.isNotEmpty)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                if (isDeleted) ...[
                                                  Icon(
                                                    Icons.block,
                                                    size: 16,
                                                    color:
                                                        const Color(0xFF8E8E93),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Flexible(
                                                  child: Text(
                                                    isDeleted
                                                        ? 'Deleted message'
                                                        : message.content,
                                                    style: AppFonts.bodyMedium
                                                        .copyWith(
                                                      color: isDeleted
                                                          ? const Color(
                                                              0xFF8E8E93)
                                                          : Colors
                                                              .white, // White text for better visibility
                                                      fontSize: 16,
                                                      fontWeight: FontWeight
                                                          .w500, // Higher font weight for better readability
                                                    ),
                                                    softWrap: true,
                                                    overflow:
                                                        TextOverflow.visible,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width:
                                                        8), // Space between message and timestamp
                                                Text(
                                                  _formatTime(
                                                      message.timestamp),
                                                  style:
                                                      AppFonts.caption.copyWith(
                                                    color: const Color.fromARGB(
                                                        255,
                                                        200,
                                                        200,
                                                        200), // Lighter gray - slightly duller than white
                                                    fontSize:
                                                        11, // Slightly smaller timestamp
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      // Removed duplicate timestamp - now inline with message
                                    ],
                                  ),
                                ),
                              ),
                              if (isOwnMessage) ...[
                                // No profile picture for sent messages - cleaner look
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: const Color(0xFF2C2C2E), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Reply preview
          if (_isReplying && _replyingToMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getReplyPreviewSender(),
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_currentUserId != null &&
                                _replyingToMessage?.senderId !=
                                    _currentUserId) ...[
                              const SizedBox(width: 4),
                              VerificationBadge(
                                isVerified: UserVerification
                                    .getDisplayVerificationStatus(
                                        widget.otherUser),
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getReplyPreviewText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF8E8E93),
                      size: 20,
                    ),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Message input row
          Row(
            children: [
              // Message input field with background covering entire area including camera
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8), // Reduced vertical padding from 12 to 8
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E), // Dark gray background
                    borderRadius: BorderRadius.circular(
                        32), // Increased from 24 to 32 for more rounded corners
                    border:
                        Border.all(color: const Color(0xFF2C2C2E), width: 1),
                  ),
                  child: _isRecording
                      ? GestureDetector(
                          onHorizontalDragStart: (d) {
                            _recordDragStartX = d.globalPosition.dx;
                          },
                          onHorizontalDragUpdate: (d) {
                            if (_recordDragStartX == null) return;
                            final delta =
                                d.globalPosition.dx - _recordDragStartX!;
                            if (delta < 0) {
                              setState(() {
                                _recordDragOffset = delta.clamp(-120.0, 0.0);
                              });
                            }
                          },
                          onHorizontalDragEnd: (_) {
                            if (_recordDragOffset.abs() > 80) {
                              _cancelRecording();
                            } else {
                              setState(() {
                                _recordDragOffset = 0;
                              });
                            }
                            _recordDragStartX = null;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            transform: Matrix4.translationValues(
                                _recordDragOffset, 0, 0),
                            child: Row(
                              children: [
                                const Icon(Icons.mic, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_recordDuration),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_back_ios,
                                    color: Colors.white54, size: 16),
                                const SizedBox(width: 4),
                                const Text('Slide left to cancel',
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            // Camera icon inside the background
                            IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20),
                              onPressed: _sendImage,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            // Message input field
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                focusNode: _messageFocusNode,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: const TextStyle(
                                    color: Color(
                                        0xFF8E8E93), // Light gray hint color
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                onChanged: (text) {
                                  // Immediate UI update for instant icon switching
                                  setState(() {});

                                  if (_typingTimer?.isActive ?? false) {
                                    _typingTimer?.cancel();
                                  }
                                  _typingTimer = Timer(
                                      const Duration(milliseconds: 500), () {
                                    // TODO: Implement typing indicator
                                  });
                                },
                              ),
                            ),
                            // Right-side icons inside the same container - only show when not typing
                            if (_messageController.text.isEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.mic,
                                    color: Colors.white, size: 24),
                                onPressed: _startRecording,
                                padding: const EdgeInsets.all(8),
                              ),
                              IconButton(
                                icon: const Icon(Icons.photo_library,
                                    color: Colors.white, size: 24),
                                onPressed: _sendImage,
                                padding: const EdgeInsets.all(8),
                              ),
                              IconButton(
                                icon: SvgPicture.string(
                                  '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M8.5 11C9.32843 11 10 10.3284 10 9.5C10 8.67157 9.32843 8 8.5 8C7.67157 8 7 8.67157 7 9.5C7 10.3284 7.67157 11 8.5 11Z" fill="#0F0F0F"></path> <path d="M17 9.5C17 10.3284 16.3284 11 15.5 11C14.6716 11 14 10.3284 14 9.5C14 8.67157 14.6716 8 15.5 8C16.3284 8 17 8.67157 17 9.5Z" fill="#0F0F0F"></path> <path fill-rule="evenodd" clip-rule="evenodd" d="M8.2 13C7.56149 13 6.9436 13.5362 7.01666 14.2938C7.06054 14.7489 7.2324 15.7884 7.95483 16.7336C8.71736 17.7313 9.99938 18.5 12 18.5C14.0006 18.5 15.2826 17.7313 16.0452 16.7336C16.7676 15.7884 16.9395 14.7489 16.9833 14.2938C17.0564 13.5362 16.4385 13 15.8 13H8.2ZM9.54387 15.5191C9.41526 15.3509 9.31663 15.1731 9.2411 15H14.7589C14.6834 15.1731 14.5847 15.3509 14.4561 15.5191C14.0981 15.9876 13.4218 16.5 12 16.5C10.5782 16.5 9.90187 15.9876 9.54387 15.5191Z" fill="#0F0F0F"></path> <path fill-rule="evenodd" clip-rule="evenodd" d="M12 23C18.0751 23 23 18.0751 23 12C23 5.92487 18.0751 1 12 1C5.92487 1 1 5.92487 1 12C1 18.0751 5.92487 23 12 23ZM12 20.9932C7.03321 20.9932 3.00683 16.9668 3.00683 12C3.00683 7.03321 7.03321 3.00683 12 3.00683C16.9668 3.00683 20.9932 7.03321 20.9932 12C20.9932 16.9668 16.9668 20.9932 12 20.9932Z" fill="#0F0F0F"></path> </g></svg>',
                                  width: 24,
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                      Colors.white, BlendMode.srcIn),
                                ),
                                onPressed: () {
                                  // TODO: Implement emoji picker
                                },
                                padding: const EdgeInsets.all(8),
                              ),
                            ] else ...[
                              // Send button when typing
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFF8B5CF6), // Purple background
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white, size: 20),
                                  onPressed: _sendMessage,
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              if (_isRecording)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _stopAndSendRecording,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  // Safe navigation method to prevent multiple navigation calls
  void _safePop() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // Send push notification to the other user
  Future<void> _sendPushNotification(String messageContent) async {
    try {
      final notificationService = NotificationService();
      final currentUser = _authService.currentUser;

      if (currentUser != null) {
        await notificationService.sendNotificationToUser(
          userId: widget.otherUser.uid,
          title: currentUser.displayName ?? 'Someone',
          body: messageContent,
          data: {
            'type': 'chat_message',
            'senderId': currentUser.uid,
            'senderName': currentUser.displayName ?? 'Unknown',
            'chatId': '${currentUser.uid}_${widget.otherUser.uid}',
          },
        );
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Mark messages as read when returning to the chat
      _markMessagesAsRead();
      // Don't scroll here to avoid interfering with user interactions
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't scroll here to avoid interfering with user interactions
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cancel all timers
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _markAsReadTimer?.cancel();
    _interactionTimer?.cancel();

    // Dispose audio players
    for (final p in _audioPlayers.values) {
      p.release();
      p.dispose();
    }

    // Dispose controllers and focus nodes
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();

    super.dispose();
  }
}
