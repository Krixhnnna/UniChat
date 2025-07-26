import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

class SettingsScreen extends StatefulWidget {
  final UserModel currentUser;

  const SettingsScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _preferredGender;
  late RangeValues _ageRange;
  late TextEditingController _locationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _preferredGender = widget.currentUser.interestedIn ?? 'Everyone';
    // Initialize age range with user's preferences if available, otherwise defaults
    double minAge = 18.0;
    double maxAge = 60.0;

    // Fetch preferences from the current user's document if they exist
    // This requires fetching the raw document as these fields are not in UserModel directly
    // and were added as separate updates.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userService = Provider.of<UserService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final String? uid = authService.currentUser?.uid;

      if (uid != null) {
        DocumentSnapshot userDoc = await userService.usersCollection.doc(uid).get(); // Access public usersCollection
        if (userDoc.exists) {
          Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            setState(() {
              _preferredGender = userData['interestedIn'] ?? 'Everyone';
              minAge = (userData['minAgePreference'] as int?)?.toDouble() ?? 18.0;
              maxAge = (userData['maxAgePreference'] as int?)?.toDouble() ?? 60.0;
              _ageRange = RangeValues(minAge.clamp(18.0, 60.0), maxAge.clamp(18.0, 60.0));
              _locationController.text = userData['locationPreference'] ?? '';
            });
          }
        }
      }
    });

    _ageRange = RangeValues(minAge.clamp(18.0, 60.0), maxAge.clamp(18.0, 60.0));
    _locationController = TextEditingController(text: widget.currentUser.location);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final String? uid = authService.currentUser?.uid;

      if (uid != null) {
        // Create an updated UserModel with new preferences
        final updatedUser = UserModel(
          uid: widget.currentUser.uid,
          email: widget.currentUser.email,
          name: widget.currentUser.name,
          bio: widget.currentUser.bio,
          gender: widget.currentUser.gender,
          interestedIn: _preferredGender, // Update interestedIn based on selection
          age: widget.currentUser.age,
          location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
          photoUrls: widget.currentUser.photoUrls,
          fcmToken: widget.currentUser.fcmToken,
          blockedUsers: widget.currentUser.blockedUsers,
          isOnline: widget.currentUser.isOnline,
          lastActive: widget.currentUser.lastActive,
          boostEndTime: widget.currentUser.boostEndTime,
        );

        // Save age range and location as separate fields for matching
        Map<String, dynamic> preferenceUpdates = {
          'interestedIn': _preferredGender,
          'minAgePreference': _ageRange.start.round(),
          'maxAgePreference': _ageRange.end.round(),
          'locationPreference': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        };

        await userService.createUserProfile(updatedUser);
        await userService.usersCollection.doc(uid).update(preferenceUpdates); // Access public usersCollection

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preferences saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preferences: $e')),
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
        title: Text('Match Preferences'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Looking For',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _preferredGender,
                    decoration: InputDecoration(
                      labelText: 'Interested In',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    items: <String>['Male', 'Female', 'Everyone']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _preferredGender = newValue!;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Age Range',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(height: 10),
                  RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 60,
                    divisions: 42,
                    labels: RangeLabels(
                      _ageRange.start.round().toString(),
                      _ageRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues newValues) {
                      setState(() {
                        _ageRange = newValues;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Min Age: ${_ageRange.start.round()}'),
                        Text('Max Age: ${_ageRange.end.round()}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Location Preference',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location (e.g., City)',
                      hintText: 'Enter city or region',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                  ),
                  SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _savePreferences,
                      child: Text('Save Preferences'),
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
    );
  }
}
