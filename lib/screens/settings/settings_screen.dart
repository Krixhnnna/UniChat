// lib/screens/settings/settings_screen.dart
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/widgets/verification_badge.dart';
import 'package:campus_crush/utils/user_verification.dart';
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  User? _currentUser;
  bool _isLoadingUser = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentFirebaseUser = authService.currentUser;

    if (currentFirebaseUser != null) {
      try {
        User? user = await userService.getUser(currentFirebaseUser.uid);
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
      } catch (e) {
        print('Error fetching current user profile for SettingsScreen: $e');
        setState(() {
          _isLoadingUser = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile data.')),
        );
      }
    } else {
      setState(() {
        _isLoadingUser = false;
      });
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final authService = Provider.of<AuthService>(context);
    final double topContentPadding = MediaQuery.of(context).padding.top +
        AppBar().preferredSize.height +
        16.0;

    return Scaffold(
      appBar: null, // Removed AppBar from SettingsScreen to prevent conflicts
      backgroundColor: Colors
          .transparent, // Set to transparent to see HomeScreen's background
      body: _isLoadingUser
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.lightTheme.primaryColor,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                  top: topContentPadding,
                  bottom:
                      16.0), // Padding to push content below the HomeScreens's AppBar
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  if (_currentUser != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      child: AspectRatio(
                        aspectRatio: 0.8,
                        child: _buildProfileCard(context, _currentUser!),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading:
                        const Icon(Icons.person, color: Colors.white, size: 28),
                    title: const Text('Edit Profile',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    onTap: () async {
                      final currentFirebaseUser = authService.currentUser;
                      if (currentFirebaseUser != null) {
                        final userService =
                            Provider.of<UserService>(context, listen: false);
                        final currentUserModel =
                            await userService.getUser(currentFirebaseUser.uid);
                        if (currentUserModel != null) {
                          await Navigator.pushNamed(context, '/edit_profile',
                              arguments: currentUserModel);
                          _fetchCurrentUserProfile();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to load profile data.')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'You need to be logged in to edit your profile.')),
                        );
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.notifications,
                        color: Colors.white, size: 28),
                    title: const Text('Notification Settings',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Notification Settings (Coming Soon!)')),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.security,
                        color: Colors.white, size: 28),
                    title: const Text('Privacy Policy',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Privacy Policy (Coming Soon!)')),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(BuildContext context, User user) {
    final String imageUrl = user.profilePhotos.isNotEmpty
        ? user.profilePhotos[0]
        : 'assets/defaultpfp.png';

    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                Image.asset('assets/defaultpfp.png', fit: BoxFit.cover),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user.displayName ?? 'N/A'}, ${user.age ?? ''}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.fontFamily,
                              ),
                    ),
                    const SizedBox(width: 8),
                    VerificationBadge(
                      isVerified:
                          UserVerification.getDisplayVerificationStatus(user),
                      size: 20,
                    ),
                  ],
                ),
                if (user.college != null && user.college!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      user.college!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (user.gender != null && user.gender!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      user.gender!,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  user.bio ?? 'No bio available.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily:
                            Theme.of(context).textTheme.bodyLarge?.fontFamily,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
