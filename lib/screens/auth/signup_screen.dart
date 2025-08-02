// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:campus_crush/widgets/animated_background.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;


class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false;
  bool _isPasswordVisible = false; // New state variable for password visibility


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }


  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final userService = Provider.of<UserService>(context, listen: false);

      // Determine college and display name based on email domain
      String collegeName;
      String displayName;
      final email = _emailController.text.trim();

      if (email.endsWith('@lpu.in') || email.endsWith('@lpunetwork.edu.ph')) {
        collegeName = 'Lovely Professional University';
        final namePart = email.split('@')[0];
        final cleanedNamePart = namePart.replaceAll(RegExp(r'[0-9]'), '');
        final nameSegments = cleanedNamePart.split('.');
        
        if (nameSegments.length >= 2) {
          displayName = nameSegments.map((s) {
            if (s.isEmpty) return '';
            return s[0].toUpperCase() + s.substring(1);
          }).join(' ');
        } else if (nameSegments.isNotEmpty) {
          displayName = nameSegments[0][0].toUpperCase() + nameSegments[0].substring(1);
        }
        else {
          displayName = '';
        }
      } else {
        collegeName = '';
        displayName = '';
      }


      try {
        firebase_auth.UserCredential userCredential = await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );

        String? uid = userCredential.user?.uid;

        if (uid != null) {
          User newUser = User(
            uid: uid,
            displayName: displayName,
            email: email,
            college: collegeName,
            age: int.tryParse(_ageController.text.trim()),
            gender: _selectedGender,
            profilePhotos: [],
            bio: '',
            likedUsers: [],
            dislikedUsers: [],
            matches: [],
            blockedUsers: [],
            reportedByUsers: [],
            interests: [],
            education: '',
            prompts: {},
            genderPreference: 'Both',
            minAgePreference: 18,
            maxAgePreference: 30,
          );

          await userService.createUser(newUser);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up successful! Please verify your email.')),
          );
          Navigator.of(context).pushReplacementNamed('/emailVerificationPending');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up failed. Please try again.')),
          );
        }
      } on firebase_auth.FirebaseAuthException catch (e) {
        print('Sign up error: ${e.code} - ${e.message}');
        String errorMessage = 'Sign up failed. Please try again.';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'The email address is already in use by another account.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        print('Sign up error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarVisualHeight = AppBar().preferredSize.height;

    final double fixedBottomBuffer = 60.0;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: AnimatedBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: statusBarHeight + appBarVisualHeight + 60.0,
                  bottom: keyboardHeight + fixedBottomBuffer,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create Your Account',
                        textAlign: TextAlign.center,
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
                          labelText: 'College Mail',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.email, color: Color.fromARGB(255, 7, 7, 7)),
                          labelStyle: const TextStyle(color: Color.fromARGB(179, 9, 9, 9)),
                          hintStyle: const TextStyle(color: Color.fromARGB(137, 12, 12, 12)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorStyle: TextStyle(color: Colors.orange.shade200),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: const TextStyle(color: Color.fromARGB(255, 9, 9, 9)),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your college email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          if (!value.endsWith('@lpu.in') && !value.endsWith('@lpunetwork.edu.ph')) {
                            return 'Only LPU email addresses are allowed for signup';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible, // Use _isPasswordVisible state
                        decoration: InputDecoration(
                          labelText: 'Create Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock, color: Color.fromARGB(255, 10, 10, 10)),
                          labelStyle: const TextStyle(color: Color.fromARGB(179, 9, 9, 9)),
                          hintStyle: const TextStyle(color: Color.fromARGB(137, 17, 17, 17)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton( // Add suffixIcon for password toggle
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: const Color.fromARGB(179, 10, 10, 10),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: Color.fromARGB(255, 9, 9, 9)),
                        validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        decoration: InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.cake, color: Color.fromARGB(255, 5, 0, 0)),
                          labelStyle: const TextStyle(color: Color.fromARGB(179, 11, 2, 2)),
                          hintStyle: const TextStyle(color: Color.fromARGB(137, 8, 2, 2)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(color: Color.fromARGB(255, 9, 3, 3)),
                        validator: (value) {
                          if (value!.isEmpty) return 'Please enter your age';
                          if (int.tryParse(value) == null) return 'Please enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.people, color: Color.fromARGB(255, 7, 0, 0)),
                          labelStyle: const TextStyle(color: Color.fromARGB(179, 8, 1, 1)),
                          hintStyle: const TextStyle(color: Color.fromARGB(137, 8, 1, 1)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        hint: const Text('Select Gender', style: TextStyle(color: Color.fromARGB(137, 9, 0, 0))),
                        dropdownColor: const Color.fromARGB(255, 248, 247, 247).withOpacity(0.8),
                        style: const TextStyle(color: Color.fromARGB(255, 8, 0, 0)),
                        items: const <String>['Male', 'Female', 'Non-binary']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(color: Color.fromARGB(255, 13, 1, 1))),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select your gender' : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: const Text(
                          'Already have an account? Log In',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      SizedBox(height: keyboardHeight + fixedBottomBuffer),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}