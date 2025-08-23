// lib/screens/matches/matches_screen.dart
import 'package:campus_crush/models/user_model.dart';
import 'package:campus_crush/services/user_service.dart';
import 'package:campus_crush/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/widgets/verification_badge.dart';
import 'package:campus_crush/utils/user_verification.dart';

class MatchesScreen extends StatefulWidget {
  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  List<User> _friendMatches = [];
  List<User> _crushMatches = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMatches() async {
    if (mounted)
      setState(() {
        _isLoading = true;
      });
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      // Fetch both lists in parallel for better performance
      final results = await Future.wait([
        userService.getFriendMatches(),
        userService.getCrushMatches(),
      ]);
      if (mounted) {
        setState(() {
          _friendMatches = results[0];
          _crushMatches = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      print('Error fetching matches: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load matches. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppTheme.lightTheme.primaryColor,
            indicatorWeight: 3.0,
            tabs: const [
              Tab(text: 'Crushes'),
              Tab(text: 'Friends'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          // --- FEATURE ADDED: Pull to Refresh ---
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchMatches,
                    color: AppTheme.lightTheme.primaryColor,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMatchesGrid(_crushMatches, "No crushes yet!",
                            "Keep swiping to find a crush!"),
                        _buildMatchesGrid(_friendMatches, "No friends yet!",
                            "Use the friend button to find friends!"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMatchesGrid(
      List<User> matches, String emptyTitle, String emptySubtitle) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emptyTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(emptySubtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 0.75,
      ),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/chat', arguments: match);
          },
          child: Card(
            elevation: 5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.network(
                    match.profilePhotos.isNotEmpty
                        ? match.profilePhotos[0]
                        : 'assets/default_avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/default_avatar.png',
                        fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Text(
                          '${match.displayName ?? 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      VerificationBadge(
                        isVerified:
                            UserVerification.getDisplayVerificationStatus(
                                match),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
