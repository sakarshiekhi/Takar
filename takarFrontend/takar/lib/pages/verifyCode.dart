//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
//import 'package:http/http.dart' as http;
import 'package:takar/services/api_service.dart';
import 'package:takar/pages/resetPassword.dart';

class VerifyCodePage extends StatefulWidget {
  final bool isDarkMode;
  final String email;

  const VerifyCodePage({
    super.key,
    required this.isDarkMode,
    required this.email,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final TextEditingController codeController = TextEditingController();
  bool _isLoading = false;

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
              "Verify Code",
              style: GoogleFonts.vazirmatn(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              "A 6-digit code has been sent to\n${widget.email}. Enter it below to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: themeColor.withOpacity(0.7)),
            ),
            SizedBox(height: 32),

            /// Code input
            TextFormField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: TextStyle(color: themeColor),
              decoration: InputDecoration(
                labelText: 'Enter Code',
                labelStyle: TextStyle(color: themeColor),
                prefixIcon: Icon(Icons.lock, color: themeColor),
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
            SizedBox(height: 32),

            /// Submit button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter a valid 6-digit code.")),
                  );
                  return;
                }

                setState(() => _isLoading = true);

                try {
                  final result = await ApiService.verifyCode(widget.email, code);
                  
                  if (result['success']) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResetPasswordPage(
                          isDarkMode: widget.isDarkMode,
                          email: widget.email,
                          code: code,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'])),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("An error occurred. Please try again.")),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Verify Code",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
