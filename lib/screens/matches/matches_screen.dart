import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart'; // We will create this next

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({Key? key}) : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Center(child: Text('Please log in to see your matches.'));
    }

    final userService = Provider.of<UserService>(context);

    return StreamBuilder<List<UserModel>>(
      stream: userService.getMatches(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Error fetching matches: ${snapshot.error}');
          return Center(child: Text('Error loading matches: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  'No matches yet!',
                  style: TextStyle(fontSize: 20, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Keep swiping to find new connections.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final List<UserModel> matches = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final matchedUser = matches[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12.0),
                leading: CircleAvatar(
                  radius: 30,
                  backgroundImage: matchedUser.photoUrls != null && matchedUser.photoUrls!.isNotEmpty
                      ? NetworkImage(matchedUser.photoUrls!.first) as ImageProvider
                      : AssetImage('assets/default_avatar.png'),
                  backgroundColor: Colors.grey[200],
                ),
                title: Text(
                  matchedUser.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text(
                  matchedUser.location ?? 'Unknown Location',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).primaryColor),
                onTap: () {
                  // Navigate to chat screen with the matched user
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        matchedUser: matchedUser,
                        currentUserId: _currentUserId!,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
