// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// Services
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/services/database_service.dart';

// Screens
import 'package:campus_crush/screens/auth/login_screen.dart';
import 'package:campus_crush/screens/auth/signup_screen.dart';
import 'package:campus_crush/screens/home/home_screen.dart';
import 'package:campus_crush/screens/home/swipe_screen.dart';
import 'package:campus_crush/screens/matches/matches_screen.dart';
import 'package:campus_crush/screens/matches/notifications_screen.dart';
import 'package:campus_crush/screens/chat/chat_screen.dart';
import 'package:campus_crush/screens/profile/edit_profile_screen.dart';
import 'package:campus_crush/screens/profile/view_profile_screen.dart'; // Import new screen
import 'package:campus_crush/screens/settings/settings_screen.dart';
import 'package:campus_crush/screens/auth/email_verification_pending_screen.dart';

// Theme
import 'package:campus_crush/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Temporary: You should call this once to populate fake profiles if needed, then comment it out.
  final userServiceForFakes = UserService();
  // await _createFakeProfiles(userServiceForFakes);


  // Request notification permissions
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });

  // Handle messages when the app is opened from a terminated state
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
        title: 'CampusCrush',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => SignUpScreen(),
          '/home': (context) => HomeScreen(),
          '/swipe': (context) => SwipeScreen(),
          '/matches': (context) => MatchesScreen(),
          '/notifications': (context) => NotificationsScreen(),
          '/chat': (context) {
            final user = ModalRoute.of(context)!.settings.arguments as User?;
            if (user != null) {
              return ChatScreen();
            }
            return const Text('Error: Matched user data not found for Chat');
          },
          '/edit_profile': (context) {
            final user = ModalRoute.of(context)!.settings.arguments as User?;
            if (user != null) {
              return EditProfileScreen(currentUser: user);
            }
            return const Text('Error: User data not found for Edit Profile');
          },
          '/view_profile': (context) { // New route for viewing a profile
            final user = ModalRoute.of(context)!.settings.arguments as User?;
            if (user != null) {
              return ViewProfileScreen(user: user);
            }
            return const Text('Error: User data not found for Profile View');
          },
          '/settings': (context) => SettingsScreen(),
          '/emailVerificationPending': (context) => EmailVerificationPendingScreen(),
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
                color: AppTheme.lightTheme.primaryColor,
              ),
            ),
          );
        } else if (snapshot.hasData) {
          if (snapshot.data!.emailVerified) {
            return HomeScreen();
          } else {
            return EmailVerificationPendingScreen();
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}