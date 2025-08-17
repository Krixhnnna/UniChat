// lib/screens/chat/chat_screen.dart
import 'package:campus_crush/models/message_model.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/database_service.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;
  bool _isTyping = false;
  bool _otherUserIsTyping = false;
  late User _matchedUser;
  bool _matchedUserIsOnline = false;
  Timestamp? _matchedUserLastActive;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is User) {
      _matchedUser = args;
      _fetchCurrentUserAndListenToMatchedUserStatus();
      _markMessagesAsRead();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _fetchCurrentUserAndListenToMatchedUserStatus() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.getCurrentUserId();
    if (currentUserId != null) {
      _currentUser = await userService.getUser(currentUserId);
      if (mounted) setState(() {});
      _listenToOtherUserTypingStatus();
      _listenToMatchedUserOnlineStatus();
    }
  }

  void _markMessagesAsRead() {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final currentUserId = _currentUser?.uid;
    if (currentUserId != null && _matchedUser.uid != null) {
      databaseService.markMessagesAsRead(currentUserId, _matchedUser.uid!);
    }
  }

  void _onMessageInputChanged() {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final currentUserId = _currentUser?.uid;

    if (currentUserId != null && _matchedUser.uid != null) {
      bool newTypingStatus = _messageController.text.isNotEmpty;
      if (_isTyping != newTypingStatus) {
        if(mounted) setState(() => _isTyping = newTypingStatus);
        databaseService.setTypingStatus(currentUserId, _matchedUser.uid!, newTypingStatus);
      }
    }
  }

  void _listenToOtherUserTypingStatus() {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final currentUserId = _currentUser?.uid;
    if (currentUserId != null && _matchedUser.uid != null) {
      databaseService.getTypingStatus(currentUserId, _matchedUser.uid!).listen((isTyping) {
        if (mounted) setState(() => _otherUserIsTyping = isTyping);
      });
    }
  }

  void _listenToMatchedUserOnlineStatus() {
    final userService = Provider.of<UserService>(context, listen: false);
    if (_matchedUser.uid != null) {
      userService.getUserStream(_matchedUser.uid!).listen((user) {
        if (user != null && mounted) {
          setState(() {
            _matchedUserIsOnline = user.isOnline ?? false;
            _matchedUserLastActive = user.lastActive;
          });
        }
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final currentUserId = _currentUser?.uid;
    if (currentUserId != null && _matchedUser.uid != null) {
      try {
        await databaseService.sendMessage(
            currentUserId, _matchedUser.uid!, _messageController.text.trim());
        _messageController.clear();
        _scrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } catch (e) {
        print('Error sending message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    }
  }

  void _showMessageOptions(Message message) {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null || message.isDeleted) return;
    
    bool isMyMessage = message.senderId == currentUserId;
    const reactions = ['❤️', '😂', '👍', '😢', '😮', '😡'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: reactions.map((emoji) => IconButton(
                        icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                        onPressed: () {
                          databaseService.addReactionToMessage(
                              currentUserId, _matchedUser.uid!, message.id, currentUserId, emoji);
                          Navigator.pop(context);
                        },
                      )).toList(),
                    ),
                  ),
                ),
                
                if (isMyMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Edit Message'),
                            onTap: () {
                              Navigator.pop(context);
                              _showEditMessageDialog(message);
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.delete_outline, color: Colors.red),
                            title: const Text('Unsend', style: TextStyle(color: Colors.red)),
                            onTap: () {
                              Navigator.pop(context);
                              _showUnsendMessageConfirmation(message);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(Message message) {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final editController = TextEditingController(text: message.messageContent);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                databaseService.editMessage(
                    _currentUser!.uid, _matchedUser.uid!, message.id, editController.text.trim());
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  void _showUnsendMessageConfirmation(Message message) {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend Message?'),
        content: const Text('This message will be permanently removed for everyone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Unsend', style: TextStyle(color: Colors.red)),
            onPressed: () {
              databaseService.unsendMessage(_currentUser!.uid, _matchedUser.uid!, message.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageInputChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
       return Scaffold(
        appBar: AppBar(title: Text(_matchedUser.displayName ?? 'Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final databaseService = Provider.of<DatabaseService>(context);
    final currentUserId = _currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.primaryColor,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                _matchedUser.profilePhotos.isNotEmpty
                    ? _matchedUser.profilePhotos[0]
                    : 'assets/default_avatar.png',
              ),
              radius: 20,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _matchedUser.displayName ?? 'Unknown User',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                if (_otherUserIsTyping)
                  const Text(
                    'typing...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  )
                else if (_matchedUserIsOnline)
                  const Text(
                    'Online',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                  )
                else if (_matchedUserLastActive != null)
                  Text(
                    'Last seen ${_formatLastActive(_matchedUserLastActive!.toDate())}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: databaseService.getMessages(currentUserId, _matchedUser.uid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello to ${_matchedUser.displayName ?? 'your match'}!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                    ),
                  );
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.senderId == currentUserId;

                    bool showDateSeparator = false;
                    if (index == messages.length - 1) {
                      showDateSeparator = true;
                    } else {
                      final previousMessage = messages[index + 1];
                      final currentDate = message.timestamp.toDate();
                      final previousDate = previousMessage.timestamp.toDate();
                      if (currentDate.day != previousDate.day ||
                          currentDate.month != previousDate.month ||
                          currentDate.year != previousDate.year) {
                        showDateSeparator = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              _formatDate(message.timestamp.toDate()),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        _buildMessageBubble(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: _buildMessageInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            'This message was deleted',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final reactionSummary = <String, int>{};
    message.reactions.values.forEach((emoji) {
      reactionSummary[emoji] = (reactionSummary[emoji] ?? 0) + 1;
    });

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.lightTheme.primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 15 : 0),
                  topRight: Radius.circular(isMe ? 0 : 15),
                  bottomLeft: const Radius.circular(15),
                  bottomRight: const Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(message.messageContent, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited)
                        Text(
                          'edited • ',
                          style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 10, fontStyle: FontStyle.italic),
                        ),
                      Text(
                        _formatTime(message.timestamp.toDate()),
                        style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (reactionSummary.isNotEmpty)
              Transform.translate(
                offset: const Offset(0, -8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      elevation: 2,
                      shape: const StadiumBorder(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          reactionSummary.entries.map((e) => '${e.key} ${e.value}').join(' '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: AppTheme.lightTheme.primaryColor,
            elevation: 0,
            mini: true,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastActive.day}/${lastActive.month}/${lastActive.year}';
    }
  }
}