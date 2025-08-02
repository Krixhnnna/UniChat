// lib/screens/auth/email_verification_pending_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  @override
  _EmailVerificationPendingScreenState createState() => _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState extends State<EmailVerificationPendingScreen> {
  User? _currentUser;
  bool _isEmailVerified = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _checkEmailVerification();
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
    });
    // Reload the user to get the latest email verification status
    await Provider.of<AuthService>(context, listen: false).reloadUser(); // Use the new reloadUser method
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;

    if (_currentUser != null && _currentUser!.emailVerified) {
      setState(() {
        _isEmailVerified = true;
      });
      // Navigate to home screen if email is verified
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _isEmailVerified = false;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _currentUser?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification email sent!')),
      );
    } catch (e) {
      print('Error sending verification email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send verification email. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Your Email'),
        automaticallyImplyLeading: false, // Prevent going back to sign-up
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email, size: 80, color: Colors.blue),
              SizedBox(height: 24),
              Text(
                'A verification email has been sent to ${_currentUser?.email ?? "your email address"}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              Text(
                'Please click the link in the email to verify your account. You will be redirected to the home screen automatically once verified.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 32),
              _isLoading
                  ? CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _sendVerificationEmail,
                          icon: Icon(Icons.send),
                          label: Text('Resend Verification Email'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _checkEmailVerification,
                          icon: Icon(Icons.refresh),
                          label: Text('I have verified my email'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await Provider.of<AuthService>(context, listen: false).signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}