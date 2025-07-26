import 'dart:io'; // Keep for File if needed, but not directly used for upload anymore

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const EditProfileScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _locationController;

  String? _selectedGender;
  String? _selectedInterestedIn;
  List<String> _photoUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _bioController = TextEditingController(text: widget.currentUser.bio);
    _ageController = TextEditingController(text: widget.currentUser.age?.toString());
    _locationController = TextEditingController(text: widget.currentUser.location);
    _selectedGender = widget.currentUser.gender;
    _selectedInterestedIn = widget.currentUser.interestedIn;
    _photoUrls = List.from(widget.currentUser.photoUrls ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);

    if (image != null) {
      setState(() {
        _isLoading = true; // Show loading indicator
      });
      try {
        final userService = Provider.of<UserService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        final String? uid = authService.currentUser?.uid;

        if (uid != null) {
          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          // Pass the XFile directly to the service, which handles web vs mobile
          String imageUrl = await userService.uploadProfilePhoto(uid, image, fileName);

          // Add URL to user's profile in Firestore
          await userService.addPhotoUrlToProfile(uid, imageUrl);

          setState(() {
            _photoUrls.add(imageUrl);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Photo uploaded successfully!')),
          );
        }
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  // Function to remove a photo from the profile
  Future<void> _removePhoto(String photoUrl) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final String? uid = authService.currentUser?.uid;

      if (uid != null) {
        // Remove URL from user's profile in Firestore
        await userService.removePhotoUrlFromProfile(uid, photoUrl);

        setState(() {
          _photoUrls.remove(photoUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo removed successfully!')),
        );
      }
    } catch (e) {
      print('Error removing photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove photo: $e')),
        );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to save profile changes
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final userService = Provider.of<UserService>(context, listen: false);
        final updatedUser = UserModel(
          uid: widget.currentUser.uid,
          email: widget.currentUser.email,
          name: _nameController.text.trim(),
          bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
          gender: _selectedGender,
          interestedIn: _selectedInterestedIn,
          age: int.tryParse(_ageController.text.trim()),
          location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
          photoUrls: _photoUrls,
          fcmToken: widget.currentUser.fcmToken, // Preserve existing token
          blockedUsers: widget.currentUser.blockedUsers, // Preserve existing blocked users
          isOnline: widget.currentUser.isOnline, // Preserve online status
          lastActive: widget.currentUser.lastActive, // Preserve last active time
          boostEndTime: widget.currentUser.boostEndTime, // Preserve boost end time
        );

        // Debug print: Show the data being sent to UserService
        print('EditProfileScreen: Saving user data: ${updatedUser.toMap()}');

        await userService.createUserProfile(updatedUser); // Using createUserProfile for update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context); // Go back to previous screen
      } catch (e) {
        print('Error saving profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(labelText: 'Bio'),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      decoration: InputDecoration(labelText: 'Age'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid age';
                          }
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(labelText: 'Location (e.g., City, State)'),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(labelText: 'Gender'),
                      items: <String>['Male', 'Female', 'Non-binary', 'Prefer not to say']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGender = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedInterestedIn,
                      decoration: InputDecoration(labelText: 'Interested In'),
                      items: <String>['Male', 'Female', 'Everyone']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedInterestedIn = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select who you are interested in';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    Text('Profile Photos', style: Theme.of(context).textTheme.titleLarge), // Use titleLarge
                    SizedBox(height: 8),
                    _photoUrls.isEmpty
                        ? Text('No photos yet. Add some to make your profile stand out!')
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8.0,
                              mainAxisSpacing: 8.0,
                            ),
                            itemCount: _photoUrls.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      _photoUrls[index],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey[300],
                                        child: Center(child: Icon(Icons.broken_image)),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removePhoto(_photoUrls[index]),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.red,
                                        child: Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.add_a_photo),
                        label: Text('Add Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary, // Use colorScheme.secondary
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
