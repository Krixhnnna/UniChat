import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../profile/edit_profile_screen.dart';
import '../settings/settings_screen.dart';
import 'swipe_screen.dart';
import '../matches/matches_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Removed _widgetOptions list as we will build widgets directly in the body
  // bool _fcmTokenRetrieved = false; // No longer needed

  @override
  void initState() {
    super.initState();
    // Removed all initialization logic from initState
    // FCM token retrieval is handled in main.dart and AuthService constructor
  }

  // Removed didChangeDependencies as it's no longer needed for FCM token retrieval
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  // }

  // Removed _retrieveAndSaveFcmToken function entirely

  Widget _buildProfileView(BuildContext context) { // Pass context explicitly if needed, but Provider.of uses current context
    final authService = Provider.of<AuthService>(context);
    final userService = Provider.of<UserService>(context);

    return StreamBuilder<UserModel?>(
      stream: authService.currentUser != null
          ? userService.getUserProfile(authService.currentUser!.uid).asStream()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Error fetching current user profile: ${snapshot.error}');
          return Center(child: Text('Error loading profile: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No profile found. Please create your profile!'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (authService.currentUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            currentUser: UserModel(
                              uid: authService.currentUser!.uid,
                              email: authService.currentUser!.email!,
                              name: '',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text('Create Profile'),
                ),
              ],
            ),
          );
        }

        UserModel currentUser = snapshot.data!;

        bool isProfileComplete = currentUser.name.isNotEmpty &&
            (currentUser.bio?.isNotEmpty ?? false) &&
            (currentUser.gender?.isNotEmpty ?? false) &&
            (currentUser.interestedIn?.isNotEmpty ?? false) &&
            (currentUser.age != null && currentUser.age! > 0) &&
            (currentUser.location?.isNotEmpty ?? false) &&
            (currentUser.photoUrls?.isNotEmpty ?? false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isProfileComplete)
                Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.orange.shade100,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                            SizedBox(width: 10),
                            Text(
                              'Profile Incomplete!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Complete your profile to get better matches and make your profile stand out.',
                          style: TextStyle(fontSize: 15, color: Colors.orange.shade700),
                        ),
                        SizedBox(height: 15),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(currentUser: currentUser),
                                ),
                              );
                            },
                            icon: Icon(Icons.arrow_forward),
                            label: Text('Complete Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundImage: currentUser.photoUrls != null && currentUser.photoUrls!.isNotEmpty
                          ? NetworkImage(currentUser.photoUrls!.first) as ImageProvider
                          : AssetImage('assets/default_avatar.png'),
                      backgroundColor: Colors.grey[200],
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(currentUser: currentUser),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Icon(Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: Text(
                  '${currentUser.name}, ${currentUser.age ?? 'N/A'}',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              Center(
                child: Text(
                  currentUser.email,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
              SizedBox(height: 20),
              Divider(thickness: 1, height: 30),

              _buildProfileSectionTitle('About Me'),
              SizedBox(height: 8),
              Text(
                currentUser.bio ?? 'Tell us something about yourself!',
                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              ),
              SizedBox(height: 20),

              _buildProfileSectionTitle('Details'),
              _buildProfileDetailRow(Icons.person_outline, 'Gender', currentUser.gender ?? 'Not set'),
              _buildProfileDetailRow(Icons.favorite_border, 'Interested In', currentUser.interestedIn ?? 'Not set'),
              _buildProfileDetailRow(Icons.location_on_outlined, 'Location', currentUser.location ?? 'Not set'),
              SizedBox(height: 20),

              if (currentUser.photoUrls != null && currentUser.photoUrls!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSectionTitle('My Photos'),
                    SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: currentUser.photoUrls!.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.network(
                            currentUser.photoUrls![index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[300],
                              child: Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey[600])),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              SizedBox(height: 30),

              Center(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: currentUser.isBoosted
                          ? null
                          : () async {
                              final userService = Provider.of<UserService>(context, listen: false);
                              try {
                                await userService.boostProfile(currentUser.uid, Duration(hours: 24));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Profile boosted for 24 hours!')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to boost profile: $e')),
                                );
                              }
                            },
                      icon: Icon(Icons.rocket_launch),
                      label: Text(currentUser.isBoosted ? 'Boost Active!' : 'Boost My Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentUser.isBoosted ? Colors.grey : Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),
                    if (currentUser.isBoosted && currentUser.boostEndTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Boost ends: ${DateFormat('MMM d, hh:mm a').format(currentUser.boostEndTime!.toDate())}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(currentUser: currentUser),
                      ),
                    );
                  },
                  icon: Icon(Icons.settings),
                  label: Text('Match Preferences'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ),
              SizedBox(height: 20),

              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await Provider.of<AuthService>(context, listen: false).signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  icon: Icon(Icons.logout, color: Colors.redAccent),
                  label: Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge!.copyWith(
        color: Theme.of(context).primaryColor,
      ),
    );
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine which widget to display based on _selectedIndex
    Widget currentScreen;
    switch (_selectedIndex) {
      case 0:
        currentScreen = SwipeScreen();
        break;
      case 1:
        currentScreen = MatchesScreen();
        break;
      case 2:
        currentScreen = _buildProfileView(context); // Call _buildProfileView here
        break;
      default:
        currentScreen = SwipeScreen(); // Default to swipe screen
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusCrush'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Center(
        child: currentScreen, // Display the selected screen
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Discover',
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
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).cardColor,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}
