import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';

/// Help & Support Screen
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _contactDeveloper() async {
    final url = Uri.parse('https://linktr.ee/abrarlajim');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Help & Support',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // Help Section
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: AppTheme.primaryBlue,
                      size: 32,
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    const Text(
                      'Need Help?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),
                const Text(
                  'If you have any questions, issues, or need assistance with the CityGo Supervisor app, please contact our support team.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Contact Developer Section
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Text(
                    'Contact Developer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.developer_mode, color: AppTheme.primaryGreen),
                  title: const Text(
                    'Contact Developer',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: const Text(
                    'Get in touch with the developer',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.primaryGreen),
                  onTap: _contactDeveloper,
                ),
              ],
            ),
          ),

          // FAQ Section
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildFAQItem(
                  'How do I scan an NFC card?',
                  'Tap the "Scan NFC" button on the dashboard, then hold the NFC card near your device.',
                ),
                const Divider(height: 1),
                _buildFAQItem(
                  'How do I issue a manual ticket?',
                  'Go to the dashboard, tap "Manual Ticket", fill in the passenger details, select a seat (optional), and submit.',
                ),
                const Divider(height: 1),
                _buildFAQItem(
                  'What if I\'m offline?',
                  'The app will save your actions locally and sync them when you\'re back online. Check the Sync Center for pending items.',
                ),
                const Divider(height: 1),
                _buildFAQItem(
                  'How do I view bookings?',
                  'Tap "View Bookings" on the dashboard to see all current seat bookings for your assigned bus.',
                ),
              ],
            ),
          ),

          // App Information
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                _buildInfoRow('App Name', 'CityGo Supervisor'),
                const SizedBox(height: AppTheme.spacingXS),
                _buildInfoRow('Version', '1.0.0'),
                const SizedBox(height: AppTheme.spacingXS),
                _buildInfoRow('Platform', 'Android / iOS'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingXS,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        0,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      title: Text(
        question,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Text(
          answer,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

