// lib/screens/settings/privacy_settings_screen.dart
import 'package:flutter/material.dart';
import '../../services/privacy_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_fonts.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final PrivacyService _privacyService = PrivacyService();
  final AuthService _authService = AuthService();

  String? _currentUserId;
  bool _isLoading = true;

  ReadReceiptSetting _readReceiptSetting = ReadReceiptSetting.everyone;
  OnlineStatusSetting _onlineStatusSetting = OnlineStatusSetting.everyone;
  LastSeenSetting _lastSeenSetting = LastSeenSetting.everyone;
  TypingIndicatorSetting _typingIndicatorSetting =
      TypingIndicatorSetting.everyone;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    _currentUserId = _authService.currentUser?.uid;
    if (_currentUserId != null) {
      await _privacyService.initialize(_currentUserId!);

      setState(() {
        _readReceiptSetting = _privacyService.getReadReceiptSetting();
        _onlineStatusSetting = _privacyService.getOnlineStatusSetting();
        _lastSeenSetting = _privacyService.getLastSeenSetting();
        _typingIndicatorSetting = _privacyService.getTypingIndicatorSetting();
        _isLoading = false;
      });
    }
  }

  void _updateReadReceiptSetting(ReadReceiptSetting? setting) async {
    if (setting == null || _currentUserId == null) return;

    setState(() {
      _readReceiptSetting = setting;
    });

    await _privacyService.setReadReceiptSetting(_currentUserId!, setting);
    _showSettingUpdatedSnackBar('Read receipts');
  }

  void _updateOnlineStatusSetting(OnlineStatusSetting? setting) async {
    if (setting == null || _currentUserId == null) return;

    setState(() {
      _onlineStatusSetting = setting;
    });

    await _privacyService.setOnlineStatusSetting(_currentUserId!, setting);
    _showSettingUpdatedSnackBar('Online status');
  }

  void _updateLastSeenSetting(LastSeenSetting? setting) async {
    if (setting == null || _currentUserId == null) return;

    setState(() {
      _lastSeenSetting = setting;
    });

    await _privacyService.setLastSeenSetting(_currentUserId!, setting);
    _showSettingUpdatedSnackBar('Last seen');
  }

  void _updateTypingIndicatorSetting(TypingIndicatorSetting? setting) async {
    if (setting == null || _currentUserId == null) return;

    setState(() {
      _typingIndicatorSetting = setting;
    });

    await _privacyService.setTypingIndicatorSetting(_currentUserId!, setting);
    _showSettingUpdatedSnackBar('Typing indicator');
  }

  void _showSettingUpdatedSnackBar(String settingName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$settingName setting updated'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Privacy Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Privacy Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.privacy_tip,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Controls',
                          style: AppFonts.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Control who can see your activity and information',
                          style: AppFonts.bodySmall.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Read Receipts
            _buildSettingSection(
              title: 'Read Receipts',
              description: 'Show when you\'ve read messages',
              icon: Icons.done_all,
              child: Column(
                children: ReadReceiptSetting.values.map((setting) {
                  return RadioListTile<ReadReceiptSetting>(
                    title: Text(
                      _getReadReceiptSettingText(setting),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getReadReceiptSettingDescription(setting),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: setting,
                    groupValue: _readReceiptSetting,
                    onChanged: _updateReadReceiptSetting,
                    activeColor: const Color(0xFF8B5CF6),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Online Status
            _buildSettingSection(
              title: 'Online Status',
              description: 'Show when you\'re online',
              icon: Icons.circle,
              child: Column(
                children: OnlineStatusSetting.values.map((setting) {
                  return RadioListTile<OnlineStatusSetting>(
                    title: Text(
                      _getOnlineStatusSettingText(setting),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getOnlineStatusSettingDescription(setting),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: setting,
                    groupValue: _onlineStatusSetting,
                    onChanged: _updateOnlineStatusSetting,
                    activeColor: const Color(0xFF8B5CF6),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Last Seen
            _buildSettingSection(
              title: 'Last Seen',
              description: 'Show when you were last active',
              icon: Icons.access_time,
              child: Column(
                children: LastSeenSetting.values.map((setting) {
                  return RadioListTile<LastSeenSetting>(
                    title: Text(
                      _getLastSeenSettingText(setting),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getLastSeenSettingDescription(setting),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: setting,
                    groupValue: _lastSeenSetting,
                    onChanged: _updateLastSeenSetting,
                    activeColor: const Color(0xFF8B5CF6),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Typing Indicator
            _buildSettingSection(
              title: 'Typing Indicator',
              description: 'Show when you\'re typing',
              icon: Icons.keyboard,
              child: Column(
                children: TypingIndicatorSetting.values.map((setting) {
                  return RadioListTile<TypingIndicatorSetting>(
                    title: Text(
                      _getTypingIndicatorSettingText(setting),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getTypingIndicatorSettingDescription(setting),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: setting,
                    groupValue: _typingIndicatorSetting,
                    onChanged: _updateTypingIndicatorSetting,
                    activeColor: const Color(0xFF8B5CF6),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Additional Privacy Options
            _buildAdditionalOptions(),

            const SizedBox(height: 24),

            // Privacy Info
            _buildPrivacyInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection({
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        description,
                        style: AppFonts.bodySmall.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text(
              'Blocked Users',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Manage blocked users',
              style: TextStyle(color: Colors.grey[400]),
            ),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.grey, size: 16),
            onTap: () {
              // Navigate to blocked users screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Blocked Users (Coming Soon!)')),
              );
            },
          ),
          Divider(color: Colors.grey[800], height: 1),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.orange),
            title: const Text(
              'Report & Safety',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Report issues and safety settings',
              style: TextStyle(color: Colors.grey[400]),
            ),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.grey, size: 16),
            onTap: () {
              // Navigate to report & safety screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report & Safety (Coming Soon!)')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Privacy Information',
                style: AppFonts.titleSmall.copyWith(
                  color: const Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• These settings control your privacy within the app\n'
            '• "Everyone" means all app users can see this information\n'
            '• "Matches" means only people you\'ve matched with can see this\n'
            '• "Nobody" means this information is hidden from everyone\n'
            '• Changes take effect immediately',
            style: AppFonts.bodySmall.copyWith(
              color: Colors.grey[300],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getReadReceiptSettingText(ReadReceiptSetting setting) {
    switch (setting) {
      case ReadReceiptSetting.everyone:
        return 'Everyone';
      case ReadReceiptSetting.matches:
        return 'Matches Only';
      case ReadReceiptSetting.nobody:
        return 'Nobody';
    }
  }

  String _getReadReceiptSettingDescription(ReadReceiptSetting setting) {
    switch (setting) {
      case ReadReceiptSetting.everyone:
        return 'All users can see when you\'ve read their messages';
      case ReadReceiptSetting.matches:
        return 'Only your matches can see when you\'ve read their messages';
      case ReadReceiptSetting.nobody:
        return 'Nobody can see when you\'ve read messages';
    }
  }

  String _getOnlineStatusSettingText(OnlineStatusSetting setting) {
    switch (setting) {
      case OnlineStatusSetting.everyone:
        return 'Everyone';
      case OnlineStatusSetting.matches:
        return 'Matches Only';
      case OnlineStatusSetting.nobody:
        return 'Nobody';
    }
  }

  String _getOnlineStatusSettingDescription(OnlineStatusSetting setting) {
    switch (setting) {
      case OnlineStatusSetting.everyone:
        return 'All users can see when you\'re online';
      case OnlineStatusSetting.matches:
        return 'Only your matches can see when you\'re online';
      case OnlineStatusSetting.nobody:
        return 'Nobody can see when you\'re online';
    }
  }

  String _getLastSeenSettingText(LastSeenSetting setting) {
    switch (setting) {
      case LastSeenSetting.everyone:
        return 'Everyone';
      case LastSeenSetting.matches:
        return 'Matches Only';
      case LastSeenSetting.nobody:
        return 'Nobody';
    }
  }

  String _getLastSeenSettingDescription(LastSeenSetting setting) {
    switch (setting) {
      case LastSeenSetting.everyone:
        return 'All users can see when you were last active';
      case LastSeenSetting.matches:
        return 'Only your matches can see when you were last active';
      case LastSeenSetting.nobody:
        return 'Nobody can see when you were last active';
    }
  }

  String _getTypingIndicatorSettingText(TypingIndicatorSetting setting) {
    switch (setting) {
      case TypingIndicatorSetting.everyone:
        return 'Everyone';
      case TypingIndicatorSetting.matches:
        return 'Matches Only';
      case TypingIndicatorSetting.nobody:
        return 'Nobody';
    }
  }

  String _getTypingIndicatorSettingDescription(TypingIndicatorSetting setting) {
    switch (setting) {
      case TypingIndicatorSetting.everyone:
        return 'All users can see when you\'re typing';
      case TypingIndicatorSetting.matches:
        return 'Only your matches can see when you\'re typing';
      case TypingIndicatorSetting.nobody:
        return 'Nobody can see when you\'re typing';
    }
  }
}
