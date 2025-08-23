// lib/screens/matches/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:campus_crush/screens/chat/chat_screen.dart';
import 'package:campus_crush/widgets/animated_background.dart';
import 'package:campus_crush/widgets/verification_badge.dart';
import 'package:campus_crush/utils/user_verification.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // MODIFIED: State variable to hold both user and request type
  Map<User, String> _pendingMatches = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingMatches();
  }

  Future<void> _fetchPendingMatches() async {
    if (mounted)
      setState(() {
        _isLoading = true;
      });

    final userService = Provider.of<UserService>(context, listen: false);
    try {
      final matches = await userService.getPendingMatches();
      if (mounted) {
        setState(() {
          _pendingMatches = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      print("Error fetching pending matches: $e");
    }
  }

  // NEW METHOD: To handle friending back
  Future<void> _friendBackUser(User user) async {
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      String? matchResult =
          await userService.swipeUser(user.uid, SwipeAction.friend);
      if (matchResult != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('You are now friends with ${user.displayName}!')),
        );
        Navigator.pushReplacementNamed(context, '/chat', arguments: user);
      }
      _fetchPendingMatches(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  // MODIFIED: To handle crushing back
  Future<void> _crushBackUser(User user) async {
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      String? matchResult =
          await userService.swipeUser(user.uid, SwipeAction.crush);
      if (matchResult != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You matched with ${user.displayName}!')),
        );
        Navigator.pushReplacementNamed(context, '/chat', arguments: user);
      }
      _fetchPendingMatches(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppTheme.lightTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _pendingMatches.isEmpty
                ? const Center(
                    child: Text("No new notifications",
                        style: TextStyle(color: Colors.white70, fontSize: 18)),
                  )
                : Column(
                    children: [
                      // Heading
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 6.0),
                        child: const Text(
                          'Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchPendingMatches,
                          child: ListView.builder(
                            itemCount: _pendingMatches.length,
                            itemBuilder: (context, index) {
                              final user =
                                  _pendingMatches.keys.elementAt(index);
                              final requestType =
                                  _pendingMatches[user]; // 'friend' or 'crush'

                              // --- UI LOGIC MODIFIED ---
                              bool isCrushRequest = requestType == 'crush';
                              String subtitleText = isCrushRequest
                                  ? 'Has a crush on you!'
                                  : 'Wants to be your friend!';
                              String buttonText =
                                  isCrushRequest ? 'Crush Back' : 'Friend Back';
                              VoidCallback onPressedAction = isCrushRequest
                                  ? () => _crushBackUser(user)
                                  : () => _friendBackUser(user);

                              return Card(
                                color: Colors.white.withOpacity(0.1),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                        '/view_profile',
                                        arguments: user);
                                  },
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(
                                        user.profilePhotos.isNotEmpty
                                            ? user.profilePhotos[0]
                                            : 'assets/default_avatar.png'),
                                  ),
                                  title: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.displayName ?? 'Unknown',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      VerificationBadge(
                                        isVerified: UserVerification
                                            .getDisplayVerificationStatus(user),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    subtitleText,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: onPressedAction,
                                    child: Text(buttonText),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppTheme.lightTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
