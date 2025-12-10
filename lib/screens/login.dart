import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/auth.dart';
import '../constants.dart';

/// Login Screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    // Navigate on success
    ref.listen<AsyncValue<LoginResponse?>>(authProvider, (previous, next) {
      next.whenData((loginResponse) {
        if (loginResponse != null && mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      });
      
      if (next.hasError && mounted) {
        final errorMessage = next.error.toString();
        final isServerError = errorMessage.contains('Server error') || 
                             errorMessage.contains('500') ||
                             errorMessage.contains('temporarily unavailable');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isServerError 
                    ? 'Server Error' 
                    : 'Login Failed',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage.replaceAll('Exception: ', ''),
                  style: const TextStyle(fontSize: 14),
                ),
                if (isServerError && ENABLE_DEMO_MODE) ...[
                  const SizedBox(height: 8),
                  Text(
                    '💡 Tip: Use demo mode to test the app',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentCyan,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            backgroundColor: isServerError 
              ? AppTheme.warningColor 
              : AppTheme.errorColor,
            duration: const Duration(seconds: 5),
            action: isServerError
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    _login();
                  },
                )
              : null,
          ),
        );
      }
    });
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // White Card Container
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingXL),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        boxShadow: AppTheme.cardShadowElevated,
                      ),
                      child: Column(
                        children: [
                          // Logo/Title
                          const Icon(
                            Icons.directions_bus,
                            size: 80,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(height: AppTheme.spacingLG),
                          const Text(
                            'CityGo Supervisor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          Text(
                            'Smart Bus, Smarter Travel',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXL),
                          const Text(
                            'Sign in to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXL),

                          // Email Input
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: const TextStyle(color: Colors.black54),
                              hintText: 'your@email.com',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(Icons.email, color: AppTheme.primaryGreen),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                              ),
                            ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                          const SizedBox(height: AppTheme.spacingMD),

                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: Colors.black54),
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryGreen),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                              ),
                            ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                          const SizedBox(height: AppTheme.spacingMD),
                          
                          // Demo Credentials Hint
                          if (ENABLE_DEMO_MODE)
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingSM),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                border: Border.all(
                                  color: AppTheme.accentCyan.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppTheme.accentCyan,
                                  ),
                                  const SizedBox(width: AppTheme.spacingSM),
                                  Expanded(
                                    child: Text(
                                      'Demo: $DEMO_EMAIL / $DEMO_PASSWORD',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.accentCyan,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: AppTheme.spacingXL),

                          // Login Button with Gradient
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              boxShadow: AppTheme.glowShadow,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: authState.isLoading ? null : _login,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingMD,
                                    horizontal: AppTheme.spacingLG,
                                  ),
                                  child: authState.isLoading
                                      ? const Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login, color: Colors.white, size: 20),
                                            SizedBox(width: AppTheme.spacingSM),
                                            Text(
                                              'Login',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

