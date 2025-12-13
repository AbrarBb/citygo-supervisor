import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../providers/auth_provider.dart';

/// Profile Screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getInitials(user) {
    final name = user?.name?.toString();
    final email = user?.email?.toString();
    
    if (name != null && name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    } else if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Profile',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: authAsync.when(
        data: (loginResponse) {
          final user = loginResponse?.user;
          
          return ListView(
            children: [
              // Profile Header
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryGreen,
                      child: Text(
                        _getInitials(user),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // Name
                    Text(
                      user?.name ?? 'Supervisor',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    // Email
                    Text(
                      user?.email ?? 'No email',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    // Role
                    if (user?.role != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user!.role!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Account Information
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spacingMD),
                      child: Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email, color: AppTheme.textSecondary),
                      title: const Text(
                        'Email',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      subtitle: Text(
                        user?.email ?? 'Not available',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.badge, color: AppTheme.textSecondary),
                      title: const Text(
                        'Role',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      subtitle: Text(
                        user?.role ?? 'Supervisor',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.verified_user, color: AppTheme.textSecondary),
                      title: const Text(
                        'User ID',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      subtitle: Text(
                        user?.id ?? 'Not available',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                'Error loading profile',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                error.toString(),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

