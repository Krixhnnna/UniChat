import 'package:flutter/material.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/services/image_optimization_service.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/optimized_profile_picture.dart';
import '../../theme/app_fonts.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  List<String> mediaUrls = [];
  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    mediaUrls = List.from(widget.user.mediaUrls);
  }

  Future<void> _addMedia() async {
    if (mediaUrls.length >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 media items allowed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Verify user is authenticated
      final auth = firebase_auth.FirebaseAuth.instance;
      if (auth.currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to add media'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Reduced from 1080
        maxHeight: 800, // Reduced from 1080
        imageQuality: 70, // Reduced from 85
      );

      if (image != null) {
        setState(() {
          isLoading = true;
        });

        // Upload optimized image using the service
        final downloadUrl = await ImageOptimizationService.uploadOptimizedImage(
          widget.user.uid,
          File(image.path),
          onProgress: (progress) {
            debugPrint(
                'Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );

        // Add to mediaUrls list
        if (mounted) {
          setState(() {
            mediaUrls.add(downloadUrl);
          });
        }

        // Update user document in Firestore
        await _updateUserMedia();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Media added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error adding media';
        if (e.toString().contains('unauthorized')) {
          errorMessage = 'Permission denied. Please check your account status.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'Error adding media: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserMedia() async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.updateUserMedia(widget.user.uid, mediaUrls);
    } catch (e) {
      // Log error for debugging
      debugPrint('Error updating user media: $e');
    }
  }

  Future<void> _removeMedia(int index) async {
    try {
      setState(() {
        mediaUrls.removeAt(index);
      });
      await _updateUserMedia();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing media: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Logout',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      try {
        await Provider.of<AuthService>(context, listen: false).signOut();
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Section
            Row(
              children: [
                // Profile Picture with Online Status
                Stack(
                  children: [
                    OptimizedProfilePicture(
                      imageUrl: widget.user.profilePhotos.isNotEmpty
                          ? widget.user.profilePhotos.first
                          : null,
                      radius: 40,
                      size: 80,
                    ),
                    // Online Status Indicator
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF111111),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // User Info and Action Buttons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayName ?? 'Unknown',
                        style: AppFonts.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Edit Button
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF895BE0),
                                    Color(0xFF6B46C1)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    '/edit_profile',
                                    arguments: widget.user,
                                  );
                                },
                                icon: const Icon(Icons.edit,
                                    color: Colors.white, size: 18),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Preview Button
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF895BE0),
                                    Color(0xFF6B46C1)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    '/view_profile',
                                    arguments: widget.user,
                                  );
                                },
                                icon: const Icon(Icons.visibility,
                                    color: Colors.white, size: 18),
                                label: const Text(
                                  'Preview',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Media Section
            Text(
              '${mediaUrls.length} Media',
              style: AppFonts.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            // Media Grid - Fixed + button on left, scrollable images on right
            SizedBox(
              height: 120, // Fixed height for consistent row
              child: Row(
                children: [
                  // Fixed Add Media Button on the left
                  SizedBox(
                    width: 100,
                    child: GestureDetector(
                      onTap: isLoading ? null : _addMedia,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF895BE0),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF895BE0),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.add,
                                  color: Color(0xFF895BE0),
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Scrollable Media Images on the right
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: mediaUrls.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: mediaUrls[index],
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 120,
                                    placeholder: (context, url) => Container(
                                      color: const Color(0xFF2C2C2E),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF895BE0),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: const Color(0xFF2C2C2E),
                                      child: const Center(
                                        child: Icon(
                                          Icons.error,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Remove Button
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => _removeMedia(index),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
