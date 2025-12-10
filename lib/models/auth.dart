import 'user.dart';

/// Login response model
class LoginResponse {
  final String token;
  final String apiKey;
  final User user;

  LoginResponse({
    required this.token,
    required this.apiKey,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      apiKey: json['api_key'] as String? ?? json['apikey'] as String? ?? '',
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'api_key': apiKey,
      'user': user.toJson(),
    };
  }
}

