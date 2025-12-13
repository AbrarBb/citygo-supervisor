import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../services/api_service.dart';

/// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _notificationsEnabled = true;
  bool _offlineModeEnabled = true;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'Logout',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _apiService.clearAuth();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Settings',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // Account Section
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person, color: AppTheme.textSecondary),
                  title: const Text(
                    'Profile',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.credit_card, color: AppTheme.textSecondary),
                  title: const Text(
                    'Registered Cards',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  onTap: () {
                    Navigator.pushNamed(context, '/registered-cards');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),

          // Preferences Section
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications, color: AppTheme.textSecondary),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_off, color: AppTheme.textSecondary),
                  title: const Text(
                    'Offline Mode',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Save data when offline',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  value: _offlineModeEnabled,
                  onChanged: (value) {
                    setState(() => _offlineModeEnabled = value);
                  },
                ),
              ],
            ),
          ),

          // About Section
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Text(
                    'About',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info, color: AppTheme.textSecondary),
                  title: const Text(
                    'App Version',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  trailing: const Text(
                    '1.0.0',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help, color: AppTheme.textSecondary),
                  title: const Text(
                    'Help & Support',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  onTap: () {
                    Navigator.pushNamed(context, '/help-support');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

