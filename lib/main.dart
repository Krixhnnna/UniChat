// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

// Services
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/services/database_service.dart';
import 'package:campus_crush/services/notification_service.dart';

// Screens
import 'package:campus_crush/screens/auth/login_screen.dart';
import 'package:campus_crush/screens/auth/signup_page.dart';
import 'package:campus_crush/screens/home/home_screen.dart';
import 'package:campus_crush/screens/home/swipe_screen.dart';
import 'package:campus_crush/screens/matches/matches_screen.dart';
import 'package:campus_crush/screens/matches/notifications_screen.dart';
import 'package:campus_crush/screens/chat/chat_screen.dart';
import 'package:campus_crush/screens/profile/edit_profile_screen.dart';
import 'package:campus_crush/screens/profile/view_profile_screen.dart';
import 'package:campus_crush/screens/profile/profile_screen.dart';
import 'package:campus_crush/screens/settings/settings_screen.dart';
import 'package:campus_crush/screens/auth/email_verification_pending_screen.dart';

// Theme
import 'package:campus_crush/theme/app_theme.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for better performance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase with performance optimizations
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore settings for better performance
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize notification service
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _updateUserPresence(state);
  }

  Future<void> _updateUserPresence(AppLifecycleState state) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = FieldValue.serverTimestamp();
      switch (state) {
        case AppLifecycleState.resumed:
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'isOnline': true,
            'lastActive': now,
          });
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'isOnline': false,
            'lastActive': now,
          });
          break;
        case AppLifecycleState.hidden:
          // Don't change status for hidden state
          break;
      }
    } catch (e) {
      print('Error updating user presence: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<UserService>(
          create: (_) => UserService(),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
      ],
      child: MaterialApp(
        title: 'Campus Crush',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: AuthWrapper(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
                settings: settings,
              );
            case '/signup':
              return MaterialPageRoute(
                builder: (context) => const SignUpPage(email: ''),
                settings: settings,
              );
            case '/home':
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
                settings: settings,
              );
            case '/swipe':
              return MaterialPageRoute(
                builder: (context) => SwipeScreen(),
                settings: settings,
              );
            case '/matches':
              return MaterialPageRoute(
                builder: (context) => MatchesScreen(),
                settings: settings,
              );
            case '/notifications':
              return MaterialPageRoute(
                builder: (context) => NotificationsScreen(),
                settings: settings,
              );
            case '/chat':
              return MaterialPageRoute(
                builder: (context) => ChatScreen(
                  otherUser: settings.arguments as User,
                ),
                settings: settings,
              );
            case '/edit_profile':
              return MaterialPageRoute(
                builder: (context) => EditProfileScreen(
                  currentUser: settings.arguments as User,
                ),
                settings: settings,
              );
            case '/view_profile':
              return MaterialPageRoute(
                builder: (context) => ViewProfileScreen(
                  user: settings.arguments as User,
                ),
                settings: settings,
              );
            case '/profile':
              return MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  user: settings.arguments as User,
                ),
                settings: settings,
              );
            case '/settings':
              return MaterialPageRoute(
                builder: (context) => SettingsScreen(),
                settings: settings,
              );
            case '/email_verification_pending':
              return MaterialPageRoute(
                builder: (context) => const EmailVerificationPendingScreen(),
                settings: settings,
              );
            default:
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
                settings: settings,
              );
          }
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return StreamBuilder<firebase_auth.User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.grey,
              ),
            ),
          );
        } else if (snapshot.hasData) {
          final user = snapshot.data!;
          if (user.emailVerified) {
            return HomeScreen();
          } else {
            // Check if this is a new signup by looking at Firestore
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userDocSnapshot) {
                if (userDocSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                  final userData =
                      userDocSnapshot.data!.data() as Map<String, dynamic>?;

                  // Check if user has completed profile setup (has username, name, etc.)
                  if (userData != null &&
                      userData['username'] != null &&
                      userData['name'] != null &&
                      userData['dateOfBirth'] != null) {
                    // This is a new signup with complete profile - show verification
                    return EmailVerificationPendingScreen();
                  }
                }

                // Existing user without verification or incomplete profile - go to login
                return const LoginScreen();
              },
            );
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
