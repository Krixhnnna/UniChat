// lib/screens/home/home_screen.dart
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/screens/home/swipe_screen.dart';
import 'package:campus_crush/screens/matches/matches_screen.dart';
import 'package:campus_crush/screens/settings/settings_screen.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/widgets/animated_background.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  User? _currentUser;
  bool _isLoadingUser = true;

  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
    _widgetOptions = <Widget>[
      SwipeScreen(), // Children screens no longer have their own Scaffold
      MatchesScreen(),
      SettingsScreen(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      if (_selectedIndex != args) {
        setState(() {
          _selectedIndex = args;
        });
      }
    }
  }

  Future<void> _fetchCurrentUser() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.getCurrentUserId();
    if (currentUserId != null) {
      try {
        User? user = await userService.getUser(currentUserId);
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
      } catch (e) {
        print('Error fetching current user: $e');
        setState(() {
          _isLoadingUser = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data. Please try again.')),
        );
      }
    } else {
      setState(() {
        _isLoadingUser = false;
      });
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('')),
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.lightTheme.primaryColor,
          ),
        ),
      );
    }
    
    // The single, master Scaffold for all tabs
    return Scaffold(
      appBar: AppBar(
        title: const Text('', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.lightTheme.primaryColor, // solid background color
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed('/notifications');
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: AnimatedBackground(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.lightTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
    );
  }
}