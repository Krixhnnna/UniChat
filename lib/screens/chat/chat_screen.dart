import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/database_service.dart';
import '../../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final UserModel matchedUser;
  final String currentUserId;

  const ChatScreen({
    Key? key,
    required this.matchedUser,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  UserModel? _currentUserProfile;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
    _messageController.addListener(_onMessageControllerChanged);
  }

  Future<void> _fetchCurrentUserProfile() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final user = await userService.getUserProfile(widget.currentUserId);
    setState(() {
      _currentUserProfile = user;
    });
  }

  void _onMessageControllerChanged() {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    bool currentlyTyping = _messageController.text.trim().isNotEmpty;

    if (currentlyTyping != _isTyping) {
      setState(() {
        _isTyping = currentlyTyping;
      });
      databaseService.setTypingStatus(widget.currentUserId, widget.matchedUser.uid, _isTyping);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageControllerChanged);
    _messageController.dispose();
    _scrollController.dispose();
    Provider.of<DatabaseService>(context, listen: false).setTypingStatus(
      widget.currentUserId,
      widget.matchedUser.uid,
      false,
    );
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    try {
      await databaseService.sendMessage(
        widget.currentUserId,
        widget.matchedUser.uid,
        _messageController.text.trim(),
      );
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  String _formatLastActive(Timestamp? lastActive) {
    if (lastActive == null) return 'Offline';
    final now = DateTime.now();
    final lastActiveDate = lastActive.toDate();
    final difference = now.difference(lastActiveDate);

    if (difference.inMinutes < 1) {
      return 'Online';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(lastActiveDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final databaseService = Provider.of<DatabaseService>(context);
    final userService = Provider.of<UserService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: widget.matchedUser.photoUrls != null && widget.matchedUser.photoUrls!.isNotEmpty
                  ? NetworkImage(widget.matchedUser.photoUrls!.first) as ImageProvider
                  : AssetImage('assets/default_avatar.png'),
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.matchedUser.name),
                StreamBuilder<UserModel?>(
                  stream: userService.getUserProfile(widget.matchedUser.uid).asStream(),
                  builder: (context, userSnapshot) {
                    final matchedUserLive = userSnapshot.data;
                    return StreamBuilder<bool>(
                      stream: databaseService.getTypingStatus(widget.currentUserId, widget.matchedUser.uid),
                      builder: (context, typingSnapshot) {
                        final isOtherUserTyping = typingSnapshot.hasData && typingSnapshot.data == true;

                        if (isOtherUserTyping) {
                          return Text(
                            'Typing...',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          );
                        } else if (matchedUserLive != null) {
                          String statusText = matchedUserLive.isOnline == true
                              ? 'Online'
                              : _formatLastActive(matchedUserLive.lastActive);
                          return Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: matchedUserLive.isOnline == true ? Colors.lightGreenAccent : Colors.white70,
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: databaseService.getMessages(widget.currentUserId, widget.matchedUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Error fetching chat messages: ${snapshot.error}');
                  return Center(child: Text('Error loading messages: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Say hello!', style: TextStyle(color: Colors.grey[600])));
                }

                final messages = snapshot.data!;

                return AnimatedSwitcher( // NEW: AnimatedSwitcher for smooth message list updates
                  duration: const Duration(milliseconds: 300),
                  child: ListView.builder(
                    key: ValueKey(messages.length), // Key to trigger animation on list change
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUserId;
                      final displayAvatar = isMe
                          ? (_currentUserProfile?.photoUrls != null && _currentUserProfile!.photoUrls!.isNotEmpty
                              ? NetworkImage(_currentUserProfile!.photoUrls!.first)
                              : AssetImage('assets/default_avatar.png'))
                          : (widget.matchedUser.photoUrls != null && widget.matchedUser.photoUrls!.isNotEmpty
                              ? NetworkImage(widget.matchedUser.photoUrls!.first)
                              : AssetImage('assets/default_avatar.png'));

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: displayAvatar as ImageProvider,
                                backgroundColor: Colors.grey[200],
                              ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                                    decoration: BoxDecoration(
                                      color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(isMe ? 15 : 0),
                                        topRight: Radius.circular(isMe ? 0 : 15),
                                        bottomLeft: Radius.circular(15),
                                        bottomRight: Radius.circular(15),
                                      ),
                                    ),
                                    child: Text(
                                      message.messageContent,
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    DateFormat('hh:mm a').format(message.timestamp.toDate()),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            if (isMe)
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: displayAvatar as ImageProvider,
                                backgroundColor: Colors.grey[200],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Theme.of(context).primaryColor,
                  mini: true,
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
