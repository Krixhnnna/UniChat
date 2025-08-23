// lib/screens/home/home_screen.dart
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/services/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/optimized_profile_picture.dart';
import 'package:campus_crush/screens/home/swipe_screen.dart';
import 'package:campus_crush/screens/chat/chats_list_screen.dart';
import 'package:campus_crush/screens/pings/pings_screen.dart';
import 'package:campus_crush/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  User? _currentUser;
  bool _isLoadingUser = true;
  bool _hasInitialized = false; // Track if app has been initialized
  int _totalUnreadCount = 0; // Track total unread messages

  // Cache widgets to prevent unnecessary rebuilds
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _initializeWidgets();
    // Only fetch user if not already initialized
    if (!_hasInitialized) {
      _fetchCurrentUser();
      _hasInitialized = true;
    }
    _checkPendingNotifications();
  }

  // Check for pending notifications when app opens
  void _checkPendingNotifications() {
    // Temporarily disabled due to notification service changes
    // Will be re-implemented when notification service is updated
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> navigation) {
    final type = navigation['type'];

    switch (type) {
      case 'chat':
        final chatId = navigation['chatId'];
        final senderId = navigation['senderId'];
        if (chatId != null && senderId != null) {
          // Navigate to chats tab first
          setState(() {
            _selectedIndex = 3; // Chats tab
          });
          // Then navigate to specific chat
          _navigateToChat(senderId);
        }
        break;
      case 'pings':
        // Navigate to pings tab
        setState(() {
          _selectedIndex = 2; // Pings tab
        });
        break;
    }
  }

  // Navigate to specific chat
  void _navigateToChat(String otherUserId) async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final otherUser = await userService.getUser(otherUserId);
      if (otherUser != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(otherUser: otherUser),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to chat: $e');
    }
  }

  void _initializeWidgets() {
    _widgetOptions = <Widget>[
      Container(), // Blank container for Discover (1st page)
      SwipeScreen(), // Swipe system moved to 2nd page
      PingsScreen(), // Pings moved to 3rd position
      ChatsListScreen(), // Chat moved to 4th position
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && _selectedIndex != args) {
      setState(() {
        _selectedIndex = args;
      });
    }
  }

  Future<void> _fetchCurrentUser() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.getCurrentUserId();
    if (currentUserId != null) {
      try {
        User? user = await userService.getUser(currentUserId);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _isLoadingUser = false;
          });
          // Start listening to unread message counts
          _listenToUnreadCounts(currentUserId);
        }
      } catch (e) {
        print('Error fetching current user: $e');
        if (mounted) {
          setState(() {
            _isLoadingUser = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to load user data. Please try again.')),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  // Listen to unread message counts across all chats
  void _listenToUnreadCounts(String currentUserId) {
    FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        int totalUnread = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
          if (unreadCounts != null && unreadCounts[currentUserId] != null) {
            totalUnread += (unreadCounts[currentUserId] as int);
          }
        }
        setState(() {
          _totalUnreadCount = totalUnread;
        });
      }
    });
  }

  // Build chat icon with unread count bubble
  Widget _buildChatIconWithBadge(bool isSelected) {
    return Stack(
      children: [
        SvgPicture.asset(
          isSelected
              ? 'assets/icons/chat_filled_purple.svg'
              : 'assets/icons/chat_filled_gray.svg',
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(
            isSelected ? const Color(0xFF895BE0) : Colors.white60,
            BlendMode.srcIn,
          ),
        ),
        // Unread count bubble - only show when count > 0
        if (_totalUnreadCount > 0)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E), // Red background
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF111111),
                  width: 0.5,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Center(
                child: Text(
                  _totalUnreadCount > 9 ? '9+' : _totalUnreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onItemTapped(int index) {
    // Add haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      _selectedIndex = index;
    });
  }

  bool _isProfileIncomplete() {
    if (_currentUser == null) return true;

    if (_currentUser!.displayName == null ||
        _currentUser!.displayName!.trim().isEmpty) return true;
    if (_currentUser!.bio == null || _currentUser!.bio!.trim().isEmpty)
      return true;
    if (_currentUser!.profilePhotos.isEmpty) return true;
    if (_currentUser!.gender == null || _currentUser!.gender!.trim().isEmpty)
      return true;
    if (_currentUser!.age == null || _currentUser!.age! < 18) return true;
    if (_currentUser!.college == null || _currentUser!.college!.trim().isEmpty)
      return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Only show loading if we don't have a user and are still loading
    if (_isLoadingUser && _currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF895BE0)),
        ),
      );
    }

    if (_isProfileIncomplete()) {
      return _buildIncompleteProfileScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: Text(
          const ['Discover', 'Match', 'Pings', 'Chats'][_selectedIndex],
          style: AppFonts.headlineLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            if (_currentUser != null) {
              Navigator.of(context)
                  .pushNamed('/profile', arguments: _currentUser);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Builder(
              builder: (context) {
                final imageUrl = _currentUser?.profilePhotos.isNotEmpty == true
                    ? _currentUser!.profilePhotos.first
                    : null;
                
                debugPrint('Profile picture URL: $imageUrl');
                debugPrint('Current user: ${_currentUser?.displayName}');
                debugPrint('Profile photos count: ${_currentUser?.profilePhotos.length}');
                
                // Fallback to simple CircleAvatar if OptimizedProfilePicture fails
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF111111),
                    backgroundImage: CachedNetworkImageProvider(imageUrl),
                  );
                } else {
                  return const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF111111),
                    backgroundImage: AssetImage('assets/defaultpfp.png'),
                  );
                }
              }
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/aura.png',
              width: 24,
              height: 24,
            ),
            tooltip: 'Aura',
            onPressed: () {
              // Aura icon functionality can be added here
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildIncompleteProfileScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Profile Incomplete!',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Please complete your profile to start swiping.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/edit_profile',
                        arguments: _currentUser);
                    _fetchCurrentUser();
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

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C2E), width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF895BE0),
        unselectedItemColor: Colors.white60,
        selectedIconTheme:
            const IconThemeData(size: 28, color: Color(0xFF895BE0)),
        unselectedIconTheme:
            const IconThemeData(size: 28, color: Colors.white60),
        onTap: _onItemTapped,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/home_filled_gray.svg',
              width: 28,
              height: 28,
              colorFilter:
                  const ColorFilter.mode(Colors.white60, BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/home_filled_purple.svg',
              width: 28,
              height: 28,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF895BE0), BlendMode.srcIn),
            ),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.string(
              '<svg version="1.1" id="Icons" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 32.00 32.00" xml:space="preserve" fill="#292D32" stroke="#292D32"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <style type="text/css"> .st0{fill:none;stroke:#000000;stroke-width:0.00032;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:10;} </style> <g> <path d="M17,2H7C4.2,2,2,4.2,2,7v18c0,2.8,2.2,5,5,5h10c2.8,0,5-2.2,5-5V7C22,4.2,19.8,2,17,2z M8,9c0,0.6-0.4,1-1,1S6,9.6,6,9V7 c0-0.6,0.4-1,1-1s1,0.4,1,1V9z M15.3,17.3c-0.4,0.4-1,0.7-1.6,0.7h0c-0.2,0-0.5,0-0.7-0.1V19c0.6,0,1,0.4,1,1s-0.4,1-1,1h-2 c-0.6,0-1-0.4-1-1s0.4-1,1-1v-1.1C10.8,18,10.5,18,10.3,18h0c-0.6,0-1.2-0.2-1.6-0.7c-0.9-0.9-0.9-2.4,0-3.3l2.6-2.7 c0.4-0.4,1.1-0.4,1.4,0l2.6,2.7C16.2,14.9,16.2,16.4,15.3,17.3z M18,25c0,0.6-0.4,1-1,1s-1-0.4-1-1v-2c0-0.6,0.4-1,1-1s1,0.4,1,1 V25z"></path> </g> <path d="M28.5,8.6L24,5.9v19.9l6.2-10.3C31.6,13.1,30.9,10,28.5,8.6z"></path> </g></svg>',
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Colors.white60, BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.string(
              '<svg version="1.1" id="Icons" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 32.00 32.00" xml:space="preserve" fill="#895BE0" stroke="#895BE0"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <style type="text/css"> .st0{fill:none;stroke:#000000;stroke-width:0.00032;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:10;} </style> <g> <path d="M17,2H7C4.2,2,2,4.2,2,7v18c0,2.8,2.2,5,5,5h10c2.8,0,5-2.2,5-5V7C22,4.2,19.8,2,17,2z M8,9c0,0.6-0.4,1-1,1S6,9.6,6,9V7 c0-0.6,0.4-1,1-1s1,0.4,1,1V9z M15.3,17.3c-0.4,0.4-1,0.7-1.6,0.7h0c-0.2,0-0.5,0-0.7-0.1V19c0.6,0,1,0.4,1,1s-0.4,1-1,1h-2 c-0.6,0-1-0.4-1-1s0.4-1,1-1v-1.1C10.8,18,10.5,18,10.3,18h0c-0.6,0-1.2-0.2-1.6-0.7c-0.9-0.9-0.9-2.4,0-3.3l2.6-2.7 c0.4-0.4,1.1-0.4,1.4,0l2.6,2.7C16.2,14.9,16.2,16.4,15.3,17.3z M18,25c0,0.6-0.4,1-1,1s-1-0.4-1-1v-2c0-0.6,0.4-1,1-1s1,0.4,1,1 V25z"></path> </g> <path d="M28.5,8.6L24,5.9v19.9l6.2-10.10.3C31.6,13.1,30.9,10,28.5,8.6z"></path> </g></svg>',
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF895BE0), BlendMode.srcIn),
            ),
            label: 'Match',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.string(
              '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M19.3399 14.49L18.3399 12.83C18.1299 12.46 17.9399 11.76 17.9399 11.35V8.82C17.9399 6.47 16.5599 4.44 14.5699 3.49C14.0499 2.57 13.0899 2 11.9899 2C10.8999 2 9.91994 2.59 9.39994 3.52C7.44994 4.49 6.09994 6.5 6.09994 8.82V11.35C6.09994 11.76 5.90994 12.46 5.69994 12.82L4.68994 14.49C4.28994 15.16 4.19994 15.9 4.44994 16.58C4.68994 17.25 5.25994 17.77 5.99994 18.02C7.93994 18.68 9.97994 19 12.0199 19C14.0599 19 16.0999 18.68 18.0399 18.03C18.7399 17.8 19.2799 17.27 19.5399 16.58C19.7999 15.89 19.7299 15.13 19.3399 14.49Z" fill="#292D32"/><path d="M14.8297 20.01C14.4097 21.17 13.2997 22 11.9997 22C11.2097 22 10.4297 21.68 9.87969 21.11C9.55969 20.81 9.31969 20.41 9.17969 20C9.30969 20.02 9.43969 20.03 9.57969 20.05C9.80969 20.08 10.0497 20.11 10.2897 20.13C10.8597 20.21 11.4397 20.21 12.0197 20.21C12.5897 20.21 13.1597 20.18 13.7197 20.13C13.9297 20.11 14.1397 20.1 14.3397 20.07C14.4997 20.05 14.6597 20.03 14.8297 20.01Z" fill="#292D32"/></svg>',
              width: 28,
              height: 28,
              colorFilter:
                  const ColorFilter.mode(Colors.white60, BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.string(
              '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M19.3399 14.49L18.3399 12.83C18.1299 12.46 17.9399 11.76 17.9399 11.35V8.82C17.9399 6.47 16.5599 4.44 14.5699 3.49C14.0499 2.57 13.0899 2 11.9899 2C10.8999 2 9.91994 2.59 9.39994 3.52C7.44994 4.49 6.09994 6.5 6.09994 8.82V11.35C6.09994 11.76 5.90994 12.46 5.69994 12.82L4.68994 14.49C4.28994 15.16 4.19994 15.9 4.44994 16.58C4.68994 17.25 5.25994 17.77 5.99994 18.02C7.93994 18.68 9.97994 19 12.0199 19C14.0599 19 16.0999 18.68 18.0399 18.03C18.7399 17.8 19.2799 17.27 19.5399 16.58C19.7999 15.89 19.7299 15.13 19.3399 14.49Z" fill="#895BE0"/><path d="M14.8297 20.01C14.4097 21.17 13.2997 22 11.9997 22C11.2097 22 10.4297 21.68 9.87969 21.11C9.55969 20.81 9.31969 20.41 9.17969 20C9.30969 20.02 9.43969 20.03 9.57969 20.05C9.80969 20.08 10.0497 20.11 10.2897 20.13C10.8597 20.21 11.4397 20.21 12.0197 20.21C12.5897 20.21 13.1597 20.18 13.7197 20.13C13.9297 20.11 14.1397 20.1 14.3397 20.07C14.4997 20.05 14.6597 20.03 14.8297 20.01Z" fill="#895BE0"/></svg>',
              width: 28,
              height: 28,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF895BE0), BlendMode.srcIn),
            ),
            label: 'Pings',
          ),
          BottomNavigationBarItem(
            icon: _buildChatIconWithBadge(false),
            activeIcon: _buildChatIconWithBadge(true),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
