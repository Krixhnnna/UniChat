import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({Key? key}) : super(key: key);

  @override
  _SwipeScreenState createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  List<UserModel> _potentialMatches = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _currentUserId;
  UserModel? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _initializeSwipeScreen();
  }

  Future<void> _initializeSwipeScreen() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUserId = authService.currentUser?.uid;

    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final userService = Provider.of<UserService>(context, listen: false);
    _currentUserProfile = await userService.getUserProfile(_currentUserId!);

    DocumentSnapshot currentUserDoc = await userService.usersCollection.doc(_currentUserId!).get();
    Map<String, dynamic>? userData = currentUserDoc.data() as Map<String, dynamic>?;

    String? genderPreference = userData?['interestedIn'] as String?;
    int? minAgePreference = userData?['minAgePreference'] as int?;
    int? maxAgePreference = userData?['maxAgePreference'] as int?;
    String? locationPreference = userData?['locationPreference'] as String?;

    userService.getPotentialMatches(
      _currentUserId!,
      genderPreference: genderPreference,
      minAge: minAgePreference,
      maxAge: maxAgePreference,
      locationFilter: locationPreference,
    ).listen((users) {
      setState(() {
        _potentialMatches = users;
        _isLoading = false;
        _currentIndex = 0;
      });
    }, onError: (error) {
      print('Error fetching potential matches: $error');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading matches: $error')),
      );
    });
  }


  void _handleSwipe(String swipedUserId, String action) async {
    if (_currentUserId == null) return;

    final userService = Provider.of<UserService>(context, listen: false);
    try {
      await userService.recordSwipe(_currentUserId!, swipedUserId, action);

      if (action == 'liked') {
        final matchDoc = await userService.getMatchDocument(_currentUserId!, swipedUserId);
        if (matchDoc != null && matchDoc.exists && matchDoc['status'] == 'matched') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('It\'s a Match! You and ${_potentialMatches[_currentIndex].name} liked each other!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      setState(() {
        _currentIndex++;
      });
    } catch (e) {
      print('Error recording swipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record swipe: $e')),
      );
    }
  }

  void _showReportDialog(BuildContext context, UserModel reportedUser) {
    String? _reportReason;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Report ${reportedUser.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please select a reason for reporting this user:'),
              DropdownButtonFormField<String>(
                value: _reportReason,
                hint: Text('Select reason'),
                items: <String>[
                  'Inappropriate content',
                  'Harassment',
                  'Spam',
                  'Fake profile',
                  'Other',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  _reportReason = newValue;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a reason';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text('Report'),
              onPressed: () async {
                if (_reportReason != null && _reportReason!.isNotEmpty) {
                  final userService = Provider.of<UserService>(context, listen: false);
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final String? currentUserId = authService.currentUser?.uid;

                  if (currentUserId != null) {
                    await userService.reportUser(currentUserId, reportedUser.uid, _reportReason!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('User reported successfully!')),
                    );
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _currentIndex++;
                    });
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a report reason.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showBlockDialog(BuildContext context, UserModel userToBlock) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Block ${userToBlock.name}?'),
          content: Text('Are you sure you want to block ${userToBlock.name}? You will no longer see each other, and any existing chat will be hidden.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text('Block'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final userService = Provider.of<UserService>(context, listen: false);
                final authService = Provider.of<AuthService>(context, listen: false);
                final String? currentUserId = authService.currentUser?.uid;

                if (currentUserId != null) {
                  await userService.blockUser(currentUserId, userToBlock.uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${userToBlock.name} has been blocked.')),
                  );
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _currentIndex++;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_potentialMatches.isEmpty || _currentIndex >= _potentialMatches.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No more potential matches right now!',
              style: TextStyle(fontSize: 20, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Check back later or update your preferences.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _initializeSwipeScreen,
              icon: Icon(Icons.refresh),
              label: Text('Refresh Matches'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    UserModel currentProfile = _potentialMatches[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: UserCard(
              user: currentProfile,
              onReport: () => _showReportDialog(context, currentProfile),
              onBlock: () => _showBlockDialog(context, currentProfile),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSwipeButton(
                icon: Icons.close,
                color: Colors.redAccent,
                onPressed: () => _handleSwipe(currentProfile.uid, 'disliked'),
                label: 'Nope',
              ),
              _buildSwipeButton(
                icon: Icons.favorite,
                color: Colors.green,
                onPressed: () => _handleSwipe(currentProfile.uid, 'liked'),
                label: 'Like',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label,
          onPressed: onPressed,
          backgroundColor: color,
          child: Icon(icon, size: 30, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 5,
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class UserCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  const UserCard({
    Key? key,
    required this.user,
    this.onReport,
    this.onBlock,
  }) : super(key: key);

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> photos = widget.user.photoUrls ?? [];

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (photos.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  photos[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  // NEW: Add loadingBuilder for smoother image loading
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: Center(child: Icon(Icons.broken_image, size: 80, color: Colors.grey[600])),
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.grey[200],
              child: Center(
                child: Icon(Icons.person, size: 120, color: Colors.grey[600]),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.user.name}, ${widget.user.age ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'report' && widget.onReport != null) {
                            widget.onReport!();
                          } else if (value == 'block' && widget.onBlock != null) {
                            widget.onBlock!();
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: ListTile(
                              leading: Icon(Icons.flag),
                              title: Text('Report'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'block',
                            child: ListTile(
                              leading: Icon(Icons.block),
                              title: Text('Block'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (widget.user.location != null && widget.user.location!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          widget.user.location!,
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  SizedBox(height: 8),
                  if (widget.user.bio != null && widget.user.bio!.isNotEmpty)
                    Text(
                      widget.user.bio!,
                      style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

          if (photos.length > 1)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(photos.length, (index) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.0),
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
