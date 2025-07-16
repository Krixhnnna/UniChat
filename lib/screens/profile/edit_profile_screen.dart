import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel? user;
  const EditProfileScreen({super.key, this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _genderController;
  late TextEditingController _interestsController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _bioController = TextEditingController(text: widget.user?.bio ?? '');
    _ageController = TextEditingController(text: widget.user?.age?.toString() ?? '');
    _genderController = TextEditingController(text: widget.user?.gender ?? '');
    _interestsController = TextEditingController(text: widget.user?.interests?.join(', ') ?? '');
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final userModel = UserModel(
        id: user.uid,
        name: _nameController.text.trim(),
        email: user.email ?? '',
        bio: _bioController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _genderController.text.trim(),
        interests: _interestsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );
      await DatabaseService().createOrUpdateUser(userModel);
      if (mounted) Navigator.pop(context, userModel);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _genderController,
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestsController,
                decoration: const InputDecoration(labelText: 'Interests (comma separated)'),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _saveProfile,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 