import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:takar/pages/VerifyCode.dart';
//import 'dart:convert';
//import 'package:http/http.dart' as http;
import 'package:takar/services/api_service.dart';

class forgetPassword extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const forgetPassword({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<forgetPassword> createState() => _forgetPasswordState();
}

class _forgetPasswordState extends State<forgetPassword> {
  final TextEditingController emailController = TextEditingController();
  bool _submitted = false;
  bool _isLoading = false;

 
  Future<void> _sendResetRequest() async {
    final enteredEmail = emailController.text.trim();
    if (enteredEmail.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.requestPasswordReset(enteredEmail);
      
      if (response.contains('sent to your email')) {
        // Navigate to VerifyCodePage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyCodePage(
              isDarkMode: widget.isDarkMode,
              email: enteredEmail,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response)),
        );
      }
    } catch (e) {
      print("Exception caught: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send request. Check your connection."),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _submitted = true;
      });
    }
  }
  

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
              "Reset Password",
              style: GoogleFonts.vazirmatn(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Enter your email and we’ll send you a code to reset your password.",
              textAlign: TextAlign.center,
              style: TextStyle(color: themeColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),

            /// Email field
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: themeColor),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: themeColor),
                prefixIcon: Icon(Icons.email, color: themeColor),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey[200],
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurple),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            /// Send Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _sendResetRequest,
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        "We well send you the code",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
            ),

            /// Feedback message
            if (_submitted)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  "If this email exists in our system, a reset code will be sent.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: themeColor.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
