// lib/screens/matches/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:campus_crush/screens/chat/chat_screen.dart';
import 'package:campus_crush/widgets/animated_background.dart';


class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<User> _pendingMatches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingMatches();
  }

  Future<void> _fetchPendingMatches() async {
    setState(() {
      _isLoading = true;
    });

    final userService = Provider.of<UserService>(context, listen: false);
    try {
      final matches = await userService.getPendingMatches();
      setState(() {
        _pendingMatches = matches;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching pending matches: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load notifications.')),
      );
    }
  }

  Future<void> _likeBackUser(User user) async {
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      await userService.swipeUser(user.uid!, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You matched with ${user.displayName}!')),
      );
      await _fetchPendingMatches();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(), settings: RouteSettings(arguments: user)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to match back. Please try again.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.lightTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _pendingMatches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none, size: 80, color: Colors.white54),
                        const SizedBox(height: 20),
                        const Text(
                          'You have no new notifications.',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Keep swiping to find new matches!',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchPendingMatches,
                    color: AppTheme.lightTheme.primaryColor,
                    child: ListView.builder(
                      itemCount: _pendingMatches.length,
                      itemBuilder: (context, index) {
                        final user = _pendingMatches[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            onTap: () { // Add onTap to navigate to profile view
                              Navigator.of(context).pushNamed('/view_profile', arguments: user); // Navigate and pass user data
                            },
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(user.profilePhotos.isNotEmpty
                                  ? user.profilePhotos[0]
                                  : 'assets/default_avatar.png'),
                            ),
                            title: Text(
                              user.displayName ?? 'Unknown',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Has sent you a match request!',
                              style: TextStyle(color: Colors.white70),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _likeBackUser(user),
                              child: const Text('Match Back'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.lightTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}