// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:campus_crush/widgets/animated_background.dart';

import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';  // Temporarily disabled
import 'dart:io';
// We are no longer using the 'image' package to avoid decoding errors.
// import 'package:image/image.dart' as img;

class EditProfileScreen extends StatefulWidget {
  final User currentUser;

  const EditProfileScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _collegeController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _snapchatController;
  late TextEditingController _instagramController;
  late TextEditingController _discordController;

  String? _selectedGender;
  String? _selectedGenderPreference;
  List<String> _profilePhotos = [];
  bool _isSaving = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.currentUser.displayName);
    _collegeController =
        TextEditingController(text: widget.currentUser.college);
    _bioController = TextEditingController(text: widget.currentUser.bio);
    _ageController =
        TextEditingController(text: widget.currentUser.age?.toString() ?? '');
    _snapchatController = TextEditingController(
        text: (widget.currentUser.prompts['snapchat'] ?? '').toString());
    _instagramController = TextEditingController(
        text: (widget.currentUser.prompts['instagram'] ?? '').toString());
    _discordController = TextEditingController(
        text: (widget.currentUser.prompts['discord'] ?? '').toString());
    _selectedGender = widget.currentUser.gender;
    _profilePhotos = List.from(widget.currentUser.profilePhotos);
    _selectedGenderPreference = widget.currentUser.genderPreference;

    // Ensure dropdown values are valid; otherwise set to null to avoid assertion
    const genders = ['Male', 'Female', 'Non-binary'];
    if (_selectedGender == null || !genders.contains(_selectedGender)) {
      _selectedGender = null;
    }
    const prefs = ['Male', 'Female', 'Both'];
    if (_selectedGenderPreference == null ||
        !prefs.contains(_selectedGenderPreference)) {
      _selectedGenderPreference = null;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _collegeController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _snapchatController.dispose();
    _instagramController.dispose();
    _discordController.dispose();
    super.dispose();
  }

  // SIMPLIFIED AND MORE ROBUST _pickImage METHOD
  Future<void> _pickImage() async {
    try {
      // Pick an image and use image_picker's built-in compression.
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // Reduce dimensions and quality to speed up uploads
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        String fileExtension = image.path.split('.').last;
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        // Firebase Storage temporarily disabled
        // Reference storageRef = FirebaseStorage.instance
        //     .ref()
        //     .child('profile_photos/${widget.currentUser.uid}/$fileName');

        // // Upload the file directly from its path.
        // final uploadTask = storageRef.putFile(
        //   File(image.path),
        //   SettableMetadata(contentType: 'image/jpeg'),
        // );

        // uploadTask.snapshotEvents.listen((s) {
        //   if (s.totalBytes > 0) {
        //     setState(() {
        //       _uploadProgress = s.bytesTransferred / s.totalBytes;
        //     });
        //   }
        // });

        // final TaskSnapshot snapshot = await uploadTask;
        // String downloadUrl = await snapshot.ref.getDownloadURL();
        String downloadUrl = image.path; // Temporarily use local path

        setState(() {
          if (_profilePhotos.isNotEmpty) {
            _profilePhotos[0] = downloadUrl;
          } else {
            _profilePhotos.add(downloadUrl);
          }
          _isUploading = false;
          _uploadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
        );
      }
    } catch (e) {
      print('Error picking or uploading image: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final userService = Provider.of<UserService>(context, listen: false);

      try {
        // Update core fields
        final Map<String, dynamic> updates = {
          'displayName': _displayNameController.text.trim(),
          'college': _collegeController.text.trim(),
          'bio': _bioController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'gender': _selectedGender,
          'genderPreference': _selectedGenderPreference,
          'profilePhotos': _profilePhotos,
        };

        // Socials stored under prompts.<key>
        updates['prompts'] = {
          ...widget.currentUser.prompts,
          'snapchat': _snapchatController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'discord': _discordController.text.trim(),
        };

        await userService.updateUserFields(widget.currentUser.uid, updates);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        print('Error saving profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      } finally {
        setState(() {
          _isSaving = false;
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
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AnimatedBackground(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: statusBarHeight + appBarVisualHeight + 24.0,
                bottom: keyboardHeight + fixedBottomBuffer,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Heading
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 6.0),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Display Name
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon:
                            const Icon(Icons.person, color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 16),
                    // College
                    TextFormField(
                      controller: _collegeController,
                      decoration: InputDecoration(
                        labelText: 'College',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon:
                            const Icon(Icons.school, color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter your college' : null,
                    ),
                    const SizedBox(height: 16),
                    // Other editable fields (Bio, Age, Gender, Photos)
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon:
                            const Icon(Icons.info_outline, color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter your bio' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.cake, color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter your age';
                        if (int.tryParse(value) == null)
                          return 'Please enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon:
                            const Icon(Icons.people, color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      hint: const Text('Select Gender',
                          style: TextStyle(color: Colors.white54)),
                      dropdownColor: Colors.black.withOpacity(0.8),
                      style: const TextStyle(color: Colors.white),
                      items: const <String>['Male', 'Female', 'Non-binary']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGender = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select your gender' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGenderPreference,
                      decoration: InputDecoration(
                        labelText: 'Looking For',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.favorite_border,
                            color: Colors.white),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      hint: const Text('Select Preference',
                          style: TextStyle(color: Colors.white54)),
                      dropdownColor: Colors.black.withOpacity(0.8),
                      style: const TextStyle(color: Colors.white),
                      items: const <String>['Male', 'Female', 'Both']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGenderPreference = newValue;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select who you are looking for'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    // Socials (no TikTok)
                    const Text('Socials',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _snapchatController,
                      decoration: InputDecoration(
                        labelText: 'Snapchat',
                        prefixIcon: const Icon(Icons.chat_bubble_outline,
                            color: Colors.white),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instagramController,
                      decoration: InputDecoration(
                        labelText: 'Instagram',
                        prefixIcon: const Icon(Icons.photo_camera_outlined,
                            color: Colors.white),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _discordController,
                      decoration: InputDecoration(
                        labelText: 'Discord',
                        prefixIcon: const Icon(Icons.forum_outlined,
                            color: Colors.white),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: _profilePhotos.isNotEmpty
                            ? NetworkImage(_profilePhotos[0])
                            : const AssetImage('assets/defaultpfp.png')
                                as ImageProvider,
                        child: null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed:
                          (_isSaving || _isUploading) ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text('Upload Profile Photo',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lightTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed:
                          (_isSaving || _isUploading) ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lightTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Profile',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                    SizedBox(height: keyboardHeight + fixedBottomBuffer),
                  ],
                ),
              ),
            ),
          ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        'Uploading ${(100 * _uploadProgress).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
