import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart' as app_user;
import '../../services/user_service.dart';
import '../chat/chat_screen.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/verification_badge.dart';
import '../../utils/user_verification.dart';

class ChatsListScreen extends StatefulWidget {
  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with AutomaticKeepAliveClientMixin {
  String? currentUserId;
  app_user.User? currentUser;
  final Map<String, app_user.User> _userCache = {};

  @override
  bool get wantKeepAlive => true;

  Color _getStatusColor(app_user.User user) {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    currentUserId ??=
        Provider.of<UserService>(context, listen: false).getCurrentUserId();
    _fetchCurrentUser();
  }

  Future<void> _fetchCurrentUser() async {
    final userId = currentUserId;
    if (userId != null) {
      try {
        final userService = Provider.of<UserService>(context, listen: false);
        final user = await userService.getUser(userId);
        if (mounted) {
          setState(() {
            currentUser = user;
          });
        }
      } catch (e) {
        print('Error fetching current user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Recommended section
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recommended',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Recommended users horizontal list
            SizedBox(
              height: 130,
              child: FutureBuilder<List<app_user.User>>(
                future: _fetchRecommendedUsers(limit: 10),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) => const UserCardSkeleton(),
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemCount: 5,
                    );
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFF8B5CF6), strokeWidth: 2)));
                  }
                  final users = snapshot.data!;
                  if (users.isEmpty) {
                    return const Center(
                      child: Text('No users yet',
                          style: TextStyle(color: Colors.white60)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final photo = user.profilePhotos.isNotEmpty
                          ? user.profilePhotos.first
                          : 'assets/defaultpfp.png';
                      return GestureDetector(
                        onTap: () => _startChatWithUser(user),
                        child: Container(
                          width: 80,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundImage: photo.startsWith('http')
                                          ? CachedNetworkImageProvider(photo)
                                          : AssetImage(photo) as ImageProvider,
                                      backgroundColor: const Color(0xFF111111),
                                    ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.black, width: 2),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(user),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.displayName ?? 'User',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemCount: users.length,
                  );
                },
              ),
            ),

            // Divider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey[800]!,
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Chat threads section header
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Chats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Chat threads list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatThreadsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => const ChatSkeletonTile(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            'No chats yet',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation with someone!',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
                    ..sort((a, b) {
                      final aTime =
                          (a.data() as Map<String, dynamic>)['lastMessageTime']
                              as Timestamp?;
                      final bTime =
                          (b.data() as Map<String, dynamic>)['lastMessageTime']
                              as Timestamp?;
                      if (aTime != null && bTime != null) {
                        return bTime.compareTo(aTime);
                      }
                      return 0;
                    });

                  final otherIds = sortedDocs
                      .map((d) => ((d.data()
                              as Map<String, dynamic>)['participants'] as List)
                          .cast<String>()
                          .firstWhere((id) => id != currentUserId))
                      .toSet()
                      .toList();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _prefetchUsers(otherIds);
                  });

                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: sortedDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data =
                          sortedDocs[index].data() as Map<String, dynamic>;
                      final participants =
                          (data['participants'] as List).cast<String>();
                      final otherId =
                          participants.firstWhere((id) => id != currentUserId);
                      final lastMessage = data['lastMessage'] as String? ?? '';
                      final ts = data['lastMessageTime'] as Timestamp?;
                      final timeLabel = _relativeLabel(ts?.toDate());
                      _prefetchUsers([otherId]);
                      final user = _userCache[otherId];
                      final hasPhoto =
                          (user?.profilePhotos.isNotEmpty ?? false);
                      final unreadCount =
                          (data['unreadCounts']?[currentUserId] ?? 0);

                      return Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: unreadCount > 0
                                  ? const Color(0xFF8B5CF6).withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              if (user != null) {
                                final chatId = participants.join('_');
                                await _markMessagesAsRead(chatId);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ChatScreen(otherUser: user),
                                      settings: RouteSettings(arguments: user)),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Leading avatar
                                  Stack(
                                    children: [
                                      user != null
                                          ? Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: CircleAvatar(
                                                radius: 24,
                                                backgroundImage: hasPhoto
                                                    ? CachedNetworkImageProvider(
                                                        user.profilePhotos
                                                            .first)
                                                    : const AssetImage(
                                                            'assets/defaultpfp.png')
                                                        as ImageProvider,
                                                backgroundColor:
                                                    const Color(0xFF111111),
                                              ),
                                            )
                                          : ShimmerSkeleton(
                                              width: 48,
                                              height: 48,
                                              borderRadius: 24,
                                              baseColor: Colors.grey[800],
                                              shimmerColor: Colors.grey[600],
                                            ),
                                      if (user != null)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.black,
                                                  width: 2),
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(user),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Title and subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        user != null
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    user.displayName ?? 'User',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  VerificationBadge(
                                                    isVerified: UserVerification
                                                        .getDisplayVerificationStatus(
                                                            user),
                                                    size: 16,
                                                  ),
                                                ],
                                              )
                                            : ShimmerSkeleton(
                                                width: 120,
                                                height: 16,
                                                borderRadius: 8,
                                                baseColor: Colors.grey[800],
                                                shimmerColor: Colors.grey[600],
                                              ),
                                        const SizedBox(height: 4),
                                        user != null
                                            ? Text(
                                                unreadCount > 0
                                                    ? '$unreadCount unread message${unreadCount == 1 ? '' : 's'}'
                                                    : (lastMessage.isEmpty
                                                        ? 'Say hi 👋'
                                                        : lastMessage),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: unreadCount > 0
                                                      ? const Color(0xFF8B5CF6)
                                                      : Colors.grey[400],
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  fontSize: 14,
                                                ),
                                              )
                                            : ShimmerSkeleton(
                                                width: 200,
                                                height: 14,
                                                borderRadius: 7,
                                                baseColor: Colors.grey[800],
                                                shimmerColor: Colors.grey[600],
                                              ),
                                      ],
                                    ),
                                  ),
                                  // Trailing
                                  user != null
                                      ? (unreadCount > 0
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF8B5CF6),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF8B5CF6)
                                                            .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              timeLabel,
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12),
                                            ))
                                      : ShimmerSkeleton(
                                          width: 40,
                                          height: 14,
                                          borderRadius: 7,
                                          baseColor: Colors.grey[800],
                                          shimmerColor: Colors.grey[600],
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            _showNewChatBottomSheet();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _chatThreadsStream() {
    final uid = currentUserId;
    if (uid == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<List<app_user.User>> _fetchRecommendedUsers({int limit = 10}) async {
    final uid = currentUserId;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .limit(limit + 3)
        .get();
    final list = query.docs
        .map((d) => app_user.User.fromFirestore(d))
        .where((u) => u.uid != uid)
        .take(limit)
        .toList();
    return list;
  }

  Future<app_user.User?> _fetchUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final user = app_user.User.fromFirestore(doc);
    _userCache[uid] = user;
    return user;
  }

  Future<void> _prefetchUsers(List<String> uids) async {
    final missing = uids.where((id) => !_userCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    final chunks = <List<String>>[];
    const int batch = 10;
    for (var i = 0; i < missing.length; i += batch) {
      chunks.add(missing.sublist(
          i, i + batch > missing.length ? missing.length : i + batch));
    }
    for (final ids in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      for (final d in snap.docs) {
        _userCache[d.id] = app_user.User.fromFirestore(d);
      }
      if (mounted) setState(() {});
    }
  }

  String _relativeLabel(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '7d+';
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    if (currentUserId == null) return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCounts.$currentUserId': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _startChatWithUser(app_user.User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUser: user),
        settings: RouteSettings(arguments: user),
      ),
    );
  }

  void _showNewChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<app_user.User>>(
                future: _fetchRecommendedUsers(limit: 50),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 10,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            ShimmerSkeleton(
                              width: 40,
                              height: 40,
                              borderRadius: 20,
                              baseColor: Colors.grey[800],
                              shimmerColor: Colors.grey[600],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ShimmerSkeleton(
                                width: 150,
                                height: 16,
                                borderRadius: 8,
                                baseColor: Colors.grey[800],
                                shimmerColor: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  final users = snapshot.data!;
                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users available',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final photo = user.profilePhotos.isNotEmpty
                          ? user.profilePhotos.first
                          : 'assets/defaultpfp.png';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photo.startsWith('http')
                              ? CachedNetworkImageProvider(photo)
                              : AssetImage(photo) as ImageProvider,
                          backgroundColor: const Color(0xFF2C2C2E),
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                user.displayName ?? 'User',
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            VerificationBadge(
                              isVerified:
                                  UserVerification.getDisplayVerificationStatus(
                                      user),
                              size: 16,
                            ),
                          ],
                        ),
                        subtitle: Text(
                          user.email,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _startChatWithUser(user);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalUnreadCount() {
    return 0;
  }
}
