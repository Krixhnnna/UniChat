// lib/screens/auth/email_verification_pending_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class EmailVerificationPendingScreen extends StatefulWidget {
  final String? email;
  final String? username;
  final String? name;
  final DateTime? dateOfBirth;

  const EmailVerificationPendingScreen({
    Key? key,
    this.email,
    this.username,
    this.name,
    this.dateOfBirth,
  }) : super(key: key);

  @override
  _EmailVerificationPendingScreenState createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  User? _currentUser;
  bool _isEmailVerified = false;
  bool _isLoading = false;
  int _resendTimer = 60; // 60 seconds timer
  bool _canResend = false;
  StreamController<int>? _timerController;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _checkEmailVerification();

    // Initialize timer controller and start timer
    _timerController = StreamController<int>();
    _startResendTimer();
  }

  Timer? _timer;

  void _startResendTimer() {
    _timer?.cancel();

    // Don't close and recreate controller if it already exists
    if (_timerController == null) {
      _timerController = StreamController<int>();
    }

    // Send initial value
    _timerController?.add(_resendTimer);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendTimer > 1) {
          _resendTimer--;
          print('Timer: $_resendTimer seconds left');
          _timerController?.add(_resendTimer);
        } else {
          _resendTimer = 0;
          _canResend = true;
          print('Timer finished, can resend now');
          _timerController?.add(0);
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _resetTimer() {
    _resendTimer = 60;
    _canResend = false;
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerController?.close();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload the user to get the latest email verification status
      await Provider.of<AuthService>(context, listen: false).reloadUser();
      _currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;

      if (_currentUser != null && _currentUser!.emailVerified) {
        setState(() {
          _isEmailVerified = true;
        });

        // Complete user profile if we have signup data
        if (widget.email != null &&
            widget.username != null &&
            widget.name != null &&
            widget.dateOfBirth != null) {
          try {
            final authService =
                Provider.of<AuthService>(context, listen: false);
            await authService.completeUserProfileAfterVerification(
              _currentUser!.uid,
              widget.email!,
              widget.username!,
              widget.name!,
              widget.dateOfBirth!,
            );
            print(
                'User profile completed successfully after email verification');
          } catch (e) {
            print('Error completing user profile: $e');
            // Continue anyway - user can complete profile later
          }
        }

        // Navigate to home screen if email is verified
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Email not verified - show proper message
        setState(() {
          _isEmailVerified = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please check your email and click the verification link first!',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking email verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error checking verification status. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

      // Reset timer after sending email
      _resetTimer();
    } catch (e) {
      print('Error sending verification email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to send verification email. Please try again.')),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content perfectly centered
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Professional icon with subtle background
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 32),

                      // Main heading with better typography
                      Text(
                        'Check Your Email',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'We\'ve sent a verification email to',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),

                      // Email address in styled container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 16.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _currentUser?.email ?? "your email address",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 24),

                      // Instructions
                      Text(
                        'Click the verification link in your email to complete your account setup.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white60,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 48),

                      // Action buttons with better styling
                      _isLoading
                          ? Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF895BE0),
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Verifying...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                // Main action button
                                ElevatedButton(
                                  onPressed: _checkEmailVerification,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF895BE0),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18, horizontal: 32),
                                    minimumSize: Size(double.infinity, 60),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    shadowColor:
                                        Color(0xFF895BE0).withOpacity(0.3),
                                  ),
                                  child: const Text(
                                    'Click Here to Verify',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3),
                                  ),
                                ),
                                SizedBox(height: 24),

                                // Secondary action with timer
                                StreamBuilder<int>(
                                  stream: _timerController?.stream,
                                  builder: (context, snapshot) {
                                    final timeLeft =
                                        snapshot.data ?? _resendTimer;

                                    if (_canResend || timeLeft == 0) {
                                      return GestureDetector(
                                        onTap: _sendVerificationEmail,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20.0,
                                            vertical: 12.0,
                                          ),
                                          child: Text(
                                            'Resend Verification Link',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  Colors.grey.withOpacity(0.7),
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20.0,
                                          vertical: 12.0,
                                        ),
                                        child: Text(
                                          'Resend link in $timeLeft seconds',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
