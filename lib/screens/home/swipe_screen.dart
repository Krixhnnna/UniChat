// lib/screens/home/swipe_screen.dart
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;


class SwipeScreen extends StatefulWidget {
  @override
  _SwipeScreenState createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _rotationAnimation;
  int _currentIndex = 0;
  List<User> _potentialMatches = [];
  bool _isLoading = true;
  User? _currentUser;
  bool _isLoadingCurrentUser = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi / 8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _loadScreenData();
  }

  Future<void> _loadScreenData() async {
    await _fetchCurrentUserProfile();
    if (!_isProfileIncomplete()) {
      await _fetchPotentialMatches();
    }
    setState(() {
      _isLoadingCurrentUser = false;
      _isLoading = false;
    });
  }

  Future<void> _fetchCurrentUserProfile() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.getCurrentUserId();
    if (currentUserId != null) {
      try {
        User? user = await userService.getUser(currentUserId);
        setState(() {
          _currentUser = user;
        });
      } catch (e) {
        print('Error fetching current user profile for SwipeScreen: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load your profile data.')),
        );
      }
    }
  }

  Future<void> _fetchPotentialMatches() async {
    final userService = Provider.of<UserService>(context, listen: false);
    if (_currentUser == null) {
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final matches = await userService.getPotentialMatches();
      setState(() {
        _potentialMatches = matches;
      });
    } catch (e) {
      print('Error fetching potential matches: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load potential matches. Please try again.')),
      );
    }
  }

  bool _isProfileIncomplete() {
    if (_currentUser == null) return true;
    if (_currentUser!.displayName == null || _currentUser!.displayName!.trim().isEmpty) return true;
    if (_currentUser!.bio == null || _currentUser!.bio!.trim().isEmpty) return true;
    if (_currentUser!.profilePhotos.isEmpty) return true;
    if (_currentUser!.gender == null || _currentUser!.gender!.trim().isEmpty) return true;
    if (_currentUser!.age == null || _currentUser!.age! < 18) return true;
    if (_currentUser!.college == null || _currentUser!.college!.trim().isEmpty) return true;
    return false;
  }

  void _onSwipe(bool liked) async {
    if (_currentIndex >= _potentialMatches.length) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final swipedUser = _potentialMatches[_currentIndex];

    if (liked) {
      _swipeAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(1.5, 0.0)).animate(_animationController);
      _rotationAnimation = Tween<double>(begin: 0.0, end: math.pi / 8).animate(_animationController);
    } else {
      _swipeAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.5, 0.0)).animate(_animationController);
      _rotationAnimation = Tween<double>(begin: 0.0, end: -math.pi / 8).animate(_animationController);
    }

    _animationController.forward().then((_) {
      _animationController.reset();
      setState(() {
        if (_currentIndex < _potentialMatches.length) {
          _currentIndex++;
        }
      });
    });

    try {
      await userService.swipeUser(swipedUser.uid!, liked);
      if (liked) {
        final isMatch = await userService.checkMatch(swipedUser.uid!);
        if (isMatch) {
          _showMatchDialog(swipedUser);
        }
      }
    } catch (e) {
      print('Error swiping user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to perform swipe. Please try again.')),
      );
    }
  }

  void _showMatchDialog(User matchedUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('It\'s a Match!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(matchedUser.profilePhotos.isNotEmpty ? matchedUser.profilePhotos[0] : 'assets/default_avatar.png'),
              ),
              const SizedBox(height: 10),
              Text('You matched with ${matchedUser.displayName ?? 'Someone'}!'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Keep Swiping'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send a Message'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/chat', arguments: matchedUser);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topContentPadding = MediaQuery.of(context).padding.top + AppBar().preferredSize.height + 16.0;

    if (_isLoadingCurrentUser) {
      return Center(child: CircularProgressIndicator());
    }

    if (_isProfileIncomplete()) {
      return Padding(
        padding: EdgeInsets.only(top: topContentPadding),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
                  const SizedBox(height: 15),
                  Text(
                    'Profile Incomplete!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.lightTheme.primaryColor,
                                ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please complete your profile to start swiping and connect with others.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final userService = Provider.of<UserService>(context, listen: false);
                      final currentFirebaseUser = userService.getCurrentUserId();
                      if (currentFirebaseUser != null) {
                        final currentUserModel = await userService.getUser(currentFirebaseUser);
                        if (currentUserModel != null) {
                          await Navigator.pushNamed(
                            context,
                            '/edit_profile',
                            arguments: currentUserModel,
                          );
                          _loadScreenData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to load profile data.')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    label: const Text(
                      'Complete Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_potentialMatches.isEmpty && !_isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: topContentPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  'No new crushes around right now!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Come back later, or adjust your settings to find more people.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _fetchPotentialMatches,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    backgroundColor: AppTheme.lightTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topContentPadding),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_currentIndex + 1 < _potentialMatches.length)
                  _buildProfileCard(context, _potentialMatches[_currentIndex + 1], isBehind: true),
                if (_currentIndex + 2 < _potentialMatches.length)
                  _buildProfileCard(context, _potentialMatches[_currentIndex + 2], isBehind: true),

                if (_currentIndex < _potentialMatches.length)
                  GestureDetector(
                    onPanUpdate: (details) {
                      _animationController.value += details.delta.dx / (MediaQuery.of(context).size.width * 1.0);
                    },
                    onPanEnd: (details) {
                      if (_animationController.value > 0.4) {
                        _onSwipe(true);
                      } else if (_animationController.value < -0.4) {
                        _onSwipe(false);
                      } else {
                        _animationController.reverse();
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final offsetX = _swipeAnimation.value.dx * MediaQuery.of(context).size.width / 2;
                        final rotationAngle = _rotationAnimation.value * (_animationController.value.sign);

                        return Transform.translate(
                          offset: Offset(offsetX, 0),
                          child: Transform.rotate(
                            angle: rotationAngle,
                            alignment: Alignment.bottomCenter,
                            child: _buildProfileCard(context, _potentialMatches[_currentIndex]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'dislikeBtn',
                  onPressed: () => _onSwipe(false),
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
                FloatingActionButton(
                  heroTag: 'likeBtn',
                  onPressed: () => _onSwipe(true),
                  backgroundColor: Colors.greenAccent,
                  child: const Icon(Icons.favorite, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, User user, {bool isBehind = false}) {
    final String imageUrl = user.profilePhotos.isNotEmpty
        ? user.profilePhotos[0]
        : 'assets/default_avatar.png';

    return Center(
      child: FractionallySizedBox(
        widthFactor: isBehind ? 0.8 : 0.9,
        heightFactor: isBehind ? 0.75 : 0.85,
        child: Card(
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
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Image.asset('assets/default_avatar.png', fit: BoxFit.cover),
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
                    Text(
                      '${user.displayName ?? 'N/A'}, ${user.age ?? ''}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
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
                            fontFamily: 'IndieFlower',
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}