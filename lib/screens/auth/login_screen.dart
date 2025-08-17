// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../auth/signup_screen.dart';
import '../../models/user_model.dart';
import '../../widgets/animated_background.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signIn(_emailController.text, _passwordController.text);
        Navigator.of(context).pushReplacementNamed('/home');
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Login failed. Please check your credentials.';
        
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          errorMessage = 'Email not registered or password incorrect.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password provided for that user.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        print('Firebase Auth Error during signin: ${e.code} - ${e.message}');
      } catch (e) { // CORRECTED: Removed the extra dot
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
        print('Unexpected error during signin: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      // DEBUG PRINT STATEMENT
      print('DEBUG: Found ${userQuery.docs.length} user(s) with email $email');

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not registered. Please sign up.')),
        );
        // Important: Stop the function execution here
        return; 
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email. Please check your email.')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: ${e.message}')),
      );
      print('Firebase Auth Error during password reset: ${e.code} - ${e.message}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
      print('Unexpected error during password reset: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topSafeAreaPadding = MediaQuery.of(context).padding.top + AppBar().preferredSize.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double fixedBottomBuffer = 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.0, topSafeAreaPadding + 20.0, 16.0, keyboardHeight + fixedBottomBuffer),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Center(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email, color: Color.fromARGB(255, 8, 0, 0)),
                      labelStyle: const TextStyle(color: Color.fromARGB(179, 13, 0, 0)),
                      hintStyle: const TextStyle(color: Color.fromARGB(137, 11, 0, 0)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(color: Color.fromARGB(255, 12, 1, 1)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock, color: Color.fromARGB(255, 8, 0, 0)),
                      labelStyle: const TextStyle(color: Color.fromARGB(179, 12, 0, 0)),
                      hintStyle: const TextStyle(color: Color.fromARGB(137, 9, 0, 0)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color.fromARGB(179, 14, 1, 1),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Color.fromARGB(255, 12, 0, 0)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _signIn,
                    child: const Text('Login'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: const Color.fromARGB(255, 254, 254, 254),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}