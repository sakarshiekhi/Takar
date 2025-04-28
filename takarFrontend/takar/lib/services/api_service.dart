import 'dart:convert';
import 'package:http/http.dart' as http;

const CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000", // Your Flutter web port
];

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000'; // Use this for web/Chrome
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Use this for Android emulator
  // static const String baseUrl = 'http://localhost:8000'; // Use this for iOS simulator

  static Future<String> signup(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/signup/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return 'Signup successful!';
      } else {
        final data = jsonDecode(response.body);
        if (data is Map) {
          // Handle validation errors
          if (data.containsKey('email')) {
            return 'Email error: ${data['email'].join(', ')}';
          }
          if (data.containsKey('password')) {
            return 'Password error: ${data['password'].join(', ')}';
          }
        }
        return data['message'] ?? 'Signup failed';
      }
    } catch (e) {
      print('Error in signup: $e');
      return 'Error: Could not connect to server';
    }
  }

  static Future<String> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/login/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Store tokens if needed
        return 'Login successful!';
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Login failed';
      }
    } catch (e) {
      print('Error in login: $e');
      return 'Error: Could not connect to server';
    }
  }

  // Password Reset Methods
  static Future<String> requestPasswordReset(String email) async {
    final url = Uri.parse('$baseUrl/api/forgot-password/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Password reset email sent successfully!';
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Failed to send reset email';
      }
    } catch (e) {
      print('Error in requestPasswordReset: $e');  
      return 'Error: Could not connect to server. Please check your internet connection.';
    }
  }

  static Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final url = Uri.parse('$baseUrl/api/verify-code/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      print('Error in verifyCode: $e');
      return {
        'success': false,
        'message': 'Error: Could not connect to server. Please check your internet connection.',
      };
    }
  }

  static Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/api/reset-password/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Password reset successful!';
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Failed to reset password';
      }
    } catch (e) {
      print('Error in resetPassword: $e');  
      return 'Error: Could not connect to server. Please check your internet connection.';
    }
  }
}
