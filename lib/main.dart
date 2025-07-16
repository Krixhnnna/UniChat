import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
// Placeholder for home/profile screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CampusCrushApp());
}

class CampusCrushApp extends StatelessWidget {
  const CampusCrushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Crush',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData) {
          // TODO: Replace with Home/Profile screen
          return Scaffold(
            appBar: AppBar(title: const Text('Campus Crush')),
            body: const Center(child: Text('Logged in! (Home/Profile screen placeholder)')),
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF3366),
      body: const Center(
        child: Text(
          'Campus Crush',
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.normal,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
