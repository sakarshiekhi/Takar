import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:takar/services/api_service.dart';
import 'login.dart';

class ResetPasswordPage extends StatefulWidget {
  final bool isDarkMode;
  final String email;
  final String code;

  const ResetPasswordPage({
    super.key,
    required this.isDarkMode,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final themeColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: BackButton(color: themeColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Set New Password",
              style: GoogleFonts.pacifico(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Enter your new password below.",
              textAlign: TextAlign.center,
              style: TextStyle(color: themeColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            // New Password
            TextFormField(
              controller: passwordController,
              obscureText: !_passwordVisible,
              style: TextStyle(color: themeColor),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: themeColor),
                prefixIcon: Icon(Icons.lock, color: themeColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                    color: themeColor,
                  ),
                  onPressed: () {
                    setState(() => _passwordVisible = !_passwordVisible);
                  },
                ),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey[200],
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.deepPurple),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Confirm Password
            TextFormField(
              controller: confirmController,
              obscureText: !_confirmVisible,
              style: TextStyle(color: themeColor),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: themeColor),
                prefixIcon: Icon(Icons.lock_outline, color: themeColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmVisible ? Icons.visibility_off : Icons.visibility,
                    color: themeColor,
                  ),
                  onPressed: () {
                    setState(() => _confirmVisible = !_confirmVisible);
                  },
                ),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey[200],
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.deepPurple),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Reset Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Reset Password",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetPassword() async {
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (password.length < 6) {
      _showSnack("Password must be at least 6 characters.");
      return;
    }

    if (password != confirm) {
      _showSnack("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.resetPassword(
        email: widget.email,
        code: widget.code,
        newPassword: password,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Wait for the snackbar to complete
      await Future.delayed(const Duration(seconds: 2));

      // Check if widget is still mounted
      if (!mounted) return;

      // Navigate to login page and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => Login(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: () {},
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _showSnack("An error occurred. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}