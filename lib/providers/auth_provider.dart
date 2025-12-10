import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/auth.dart';

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<LoginResponse?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<LoginResponse?>> {
  final ApiService _apiService = ApiService();

  AuthNotifier() : super(const AsyncValue.loading()) {
    _checkAutoLogin();
  }

  /// Check if user is already logged in
  Future<void> _checkAutoLogin() async {
    final token = await _apiService.getStoredToken();
    if (token != null) {
      state = const AsyncValue.data(null); // Logged in but no need to reload
    } else {
      state = const AsyncValue.data(null);
    }
  }

  /// Login
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiService.login(email, password);
      state = AsyncValue.data(response);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Logout
  Future<void> logout() async {
    await _apiService.clearAuth();
    state = const AsyncValue.data(null);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _apiService.getStoredToken();
    return token != null;
  }
}

