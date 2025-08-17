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
    _loadScreenData();
  }
  
  Future<void> _loadScreenData() async {
    if (mounted) setState(() => _isLoadingCurrentUser = true);
    await _fetchCurrentUserProfile();
    if (_currentUser != null && !_isProfileIncomplete()) {
      await _fetchPotentialMatches();
    }
    if(mounted) setState(() => _isLoadingCurrentUser = false);
  }

  Future<void> _fetchCurrentUserProfile() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.getCurrentUserId();
    if (currentUserId != null) {
      try {
        User? user = await userService.getUser(currentUserId);
        if(mounted){
          setState(() {
            _currentUser = user;
          });
        }
      } catch (e) {
        print('Error fetching current user profile for SwipeScreen: $e');
      }
    }
  }

  Future<void> _fetchPotentialMatches() async {
    if(mounted) setState(() { _isLoading = true; });
    final userService = Provider.of<UserService>(context, listen: false);

    try {
      final matches = await userService.getPotentialMatches();
      if(mounted) {
        setState(() {
          _potentialMatches = matches;
          _currentIndex = 0;
        });
      }
    } catch (e) {
      print('Error fetching potential matches: $e');
    } finally {
       if(mounted) setState(() { _isLoading = false; });
    }
  }

  bool _isProfileIncomplete() {
    if (_currentUser == null) return true;
    if (_currentUser!.displayName == null || _currentUser!.displayName!.trim().isEmpty) return true;
    if (_currentUser!.bio == null || _currentUser!.bio!.trim().isEmpty) return true;
    if (_currentUser!.profilePhotos.isEmpty) return true;
    return false;
  }

  void _onSwipe(SwipeAction action) async {
    if (_currentIndex >= _potentialMatches.length) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final swipedUser = _potentialMatches[_currentIndex];

    _animationController.forward().then((_) {
      _animationController.reset();
      if(mounted) {
        setState(() {
          if (_currentIndex < _potentialMatches.length) {
            _currentIndex++;
          }
        });
      }
    });

    try {
      final matchResult = await userService.swipeUser(swipedUser.uid, action);
      if (matchResult != null) {
        _showMatchDialog(swipedUser, matchResult);
      }
    } catch (e) {
      print('Error swiping user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to perform swipe. Please try again.')),
      );
    }
  }

  void _showMatchDialog(User matchedUser, String matchType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(matchType == 'crush_match' ? 'It\'s a Crush!' : 'You\'re Friends!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(matchedUser.profilePhotos.isNotEmpty ? matchedUser.profilePhotos[0] : 'assets/default_avatar.png'),
              ),
              const SizedBox(height: 10),
              Text(
                matchType == 'crush_match'
                    ? 'You and ${matchedUser.displayName ?? 'Someone'} have a crush on each other!'
                    : 'You and ${matchedUser.displayName ?? 'Someone'} are now friends!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Keep Swiping'),
              onPressed: () => Navigator.of(context).pop(),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_isProfileIncomplete()) {
      return Padding(
        padding: EdgeInsets.only(top: topContentPadding),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Profile Incomplete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Please complete your profile to start swiping.', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/edit_profile', arguments: _currentUser);
                      _loadScreenData();
                    },
                    child: const Text('Complete Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchPotentialMatches,
      color: AppTheme.lightTheme.primaryColor,
      child: Padding(
        padding: EdgeInsets.only(top: topContentPadding),
        child: Column(
          children: [
            Expanded(
              child: (_potentialMatches.isEmpty && !_isLoading) 
              ? Center(
                  child: ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 20),
                      Text(
                        'No new profiles right now!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Come back later, or pull down to refresh.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Stack(
                alignment: Alignment.center,
                children: _potentialMatches.asMap().entries.map((entry) {
                  int index = entry.key;
                  User user = entry.value;

                  if (index < _currentIndex) return const SizedBox.shrink();
                  
                  if (index == _currentIndex) {
                    return GestureDetector(
                      onPanUpdate: (details) {
                        _animationController.value += details.delta.dx / (MediaQuery.of(context).size.width);
                      },
                      onPanEnd: (details) {
                        if (_animationController.value > 0.4) {
                          _onSwipe(SwipeAction.crush);
                        } else if (_animationController.value < -0.4) {
                          _onSwipe(SwipeAction.reject);
                        } else {
                          _animationController.reverse();
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_animationController.value * 500, 0),
                            child: Transform.rotate(
                              angle: _animationController.value * (math.pi / 8),
                              child: _buildProfileCard(context, user),
                            ),
                          );
                        },
                      ),
                    );
                  }
                  
                  return Transform.translate(
                    offset: Offset(0, 10.0 * (index - _currentIndex)),
                    child: _buildProfileCard(context, user, isBehind: true),
                  );
                }).toList().reversed.toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    onPressed: () => _onSwipe(SwipeAction.reject),
                    icon: Icons.close,
                    color: Colors.red,
                  ),
                  _buildActionButton(
                    onPressed: () => _onSwipe(SwipeAction.friend),
                    icon: Icons.people_outline,
                    color: Colors.blue,
                    isLarge: true,
                  ),
                  _buildActionButton(
                    onPressed: () => _onSwipe(SwipeAction.crush),
                    icon: Icons.favorite,
                    color: Colors.pink,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback onPressed, required IconData icon, required Color color, bool isLarge = false}) {
     return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, spreadRadius: 2)],
      ),
      child: FloatingActionButton(
        heroTag: icon.codePoint.toString(),
        onPressed: onPressed,
        backgroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        mini: !isLarge,
        child: Icon(icon, color: color, size: isLarge ? 40 : 25),
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
                  return Center(child: CircularProgressIndicator());
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
                    const SizedBox(height: 5),
                    Text(
                      user.bio ?? 'No bio available.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
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