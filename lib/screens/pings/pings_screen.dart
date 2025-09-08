import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart' as app_user;
import '../../services/user_service.dart';
import '../../widgets/skeleton_loading.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/verification_badge.dart';
import '../../utils/user_verification.dart';
import '../chat/chat_screen.dart';

class PingsScreen extends StatefulWidget {
  @override
  _PingsScreenState createState() => _PingsScreenState();
}

class _PingsScreenState extends State<PingsScreen>
    with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_currentUserId == null) return;

    try {
      setState(() => _isLoading = true);

      List<NotificationItem> notifications = [];

      // Add welcome notification
      notifications.add(NotificationItem.welcome());

      // Get all requests where current user is the receiver
      final snapshot = await _firestore
          .collection('requests')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;

        // Get sender's user data
        final senderUser = await _userService.getUser(senderId);
        if (senderUser != null) {
          notifications.add(NotificationItem.request(
            id: doc.id,
            sender: senderUser,
            type: data['type'] ?? 'friend',
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            status: data['status'] ?? 'pending',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRequest(String requestId, bool accept) async {
    try {
      final batch = _firestore.batch();
      final requestRef = _firestore.collection('requests').doc(requestId);

      // Get the request details
      final request = _notifications.firstWhere((r) => r.id == requestId);

      // Update request status
      batch.update(requestRef, {
        'status': accept ? 'accepted' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (accept) {
        // If accepted, create the match in users collection
        final currentUserRef =
            _firestore.collection('users').doc(_currentUserId);
        final senderUserRef =
            _firestore.collection('users').doc(request.sender!.uid);

        if (request.requestType == 'friend') {
          // Create friend match
          batch.update(currentUserRef, {
            'friendMatches': FieldValue.arrayUnion([request.sender!.uid]),
          });
          batch.update(senderUserRef, {
            'friendMatches': FieldValue.arrayUnion([_currentUserId]),
          });
        } else if (request.requestType == 'crush') {
          // Create crush match
          batch.update(currentUserRef, {
            'crushMatches': FieldValue.arrayUnion([request.sender!.uid]),
          });
          batch.update(senderUserRef, {
            'crushMatches': FieldValue.arrayUnion([_currentUserId]),
          });

          // Remove from friend matches if they were friends
          batch.update(currentUserRef, {
            'friendMatches': FieldValue.arrayRemove([request.sender!.uid]),
          });
          batch.update(senderUserRef, {
            'friendMatches': FieldValue.arrayRemove([_currentUserId]),
          });
        }
      }

      await batch.commit();

      // Remove from local list
      setState(() {
        _notifications.removeWhere((r) => r.id == requestId);
      });

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                accept ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                accept
                    ? '${request.requestType == 'crush' ? 'Crush' : 'Friend'} request accepted!'
                    : 'Request rejected',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: accept ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );

      // If accepted, show option to message
      if (accept) {
        _showMatchCreatedDialog(request.sender!, request.requestType!);
      }
    } catch (e) {
      print('Error handling request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMatchCreatedDialog(app_user.User matchedUser, String matchType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            matchType == 'crush' ? 'It\'s a Match! 💜' : 'New Friend! 👥',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: matchedUser.profilePhotos.isNotEmpty
                    ? CachedNetworkImageProvider(
                        matchedUser.profilePhotos.first)
                    : const AssetImage('assets/defaultpfp.png')
                        as ImageProvider,
              ),
              const SizedBox(height: 16),
              Text(
                'You and ${matchedUser.displayName ?? 'Someone'} are now ${matchType == 'crush' ? 'crushes' : 'friends'}!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Maybe Later',
                  style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Send a Message',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(otherUser: matchedUser),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? _buildLoadingState()
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildSkeletonTile(),
    );
  }

  Widget _buildSkeletonTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ShimmerSkeleton(
            width: 60,
            height: 60,
            borderRadius: 30,
            baseColor: Colors.grey[800],
            shimmerColor: Colors.grey[600],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(
                  width: 120,
                  height: 20,
                  borderRadius: 10,
                  baseColor: Colors.grey[800],
                  shimmerColor: Colors.grey[600],
                ),
                const SizedBox(height: 8),
                ShimmerSkeleton(
                  width: 80,
                  height: 16,
                  borderRadius: 8,
                  baseColor: Colors.grey[800],
                  shimmerColor: Colors.grey[600],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ShimmerSkeleton(
            width: 40,
            height: 16,
            borderRadius: 8,
            baseColor: Colors.grey[800],
            shimmerColor: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No new pings',
            style: AppFonts.headlineMedium.copyWith(
              color: Colors.grey[500],
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone sends you a request,\nit will appear here',
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium.copyWith(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF8B5CF6),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationTile(notification);
        },
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem notification) {
    // Handle different notification types
    if (notification.type == 'welcome') {
      return _buildWelcomeTile(notification);
    } else if (notification.type == 'request') {
      return _buildRequestTile(notification);
    }

    // Default fallback
    return Container();
  }

  Widget _buildWelcomeTile(NotificationItem notification) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title ?? 'Welcome',
                    style: AppFonts.titleLarge.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message ?? 'Make it better',
                    style: AppFonts.bodyMedium.copyWith(
                      color: Colors.grey[300],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '• now',
              style: AppFonts.caption.copyWith(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(NotificationItem notification) {
    if (notification.sender == null) return Container();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile picture
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
                radius: 30,
                backgroundImage: notification.sender!.profilePhotos.isNotEmpty
                    ? CachedNetworkImageProvider(
                        notification.sender!.profilePhotos.first)
                    : const AssetImage('assets/defaultpfp.png')
                        as ImageProvider,
                backgroundColor: const Color(0xFF111111),
              ),
            ),
            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notification.sender!.displayName ?? 'Unknown',
                            style: AppFonts.titleMedium.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          VerificationBadge(
                            isVerified:
                                UserVerification.getDisplayVerificationStatus(
                                    notification.sender!),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${notification.sender!.age ?? 'N/A'}',
                          style: AppFonts.caption.copyWith(
                            color: const Color(0xFF8B5CF6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🌍', // You can replace with flag emoji based on country
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notification.sender!.college?.split(' ').first ??
                                  'Unknown',
                              style: AppFonts.caption.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (notification.sender!.college != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        notification.sender!.college!,
                        style: AppFonts.bodySmall.copyWith(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Time and actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '• ${_getTimeAgo(notification.createdAt)}',
                  style: AppFonts.caption.copyWith(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Accept button
                    GestureDetector(
                      onTap: () => _handleRequest(notification.id, true),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reject button
                    GestureDetector(
                      onTap: () => _handleRequest(notification.id, false),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationItem {
  final String id;
  final String type; // 'welcome', 'request', 'system', etc.
  final DateTime createdAt;
  final String? title;
  final String? message;
  final app_user.User? sender;
  final String? requestType;
  final String? status;

  NotificationItem({
    required this.id,
    required this.type,
    required this.createdAt,
    this.title,
    this.message,
    this.sender,
    this.requestType,
    this.status,
  });

  // Factory constructor for welcome notification
  factory NotificationItem.welcome() {
    return NotificationItem(
      id: 'welcome',
      type: 'welcome',
      createdAt: DateTime.now(),
      title: 'Welcome to Vibee',
      message: 'Make it better',
    );
  }

  // Factory constructor for request notifications
  factory NotificationItem.request({
    required String id,
    required app_user.User sender,
    required String type,
    required DateTime createdAt,
    required String status,
  }) {
    return NotificationItem(
      id: id,
      type: 'request',
      createdAt: createdAt,
      sender: sender,
      requestType: type,
      status: status,
    );
  }
}
