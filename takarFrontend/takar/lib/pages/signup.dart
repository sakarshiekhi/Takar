import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:takar/services/api_service.dart';

class Signup extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const Signup({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<Signup> createState() => SignupPageState();
}

class SignupPageState extends State<Signup> {
  // final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Create Account",
                style: GoogleFonts.vazirmatn(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              SizedBox(height: 32),

              // _buildTextField(
              //   controller: nameController,
              //   label: 'Full Name',
              //   icon: Icons.person,
              //   isDark: isDark,
              // ),
              // SizedBox(height: 20),

              _buildTextField(
                controller: emailController,
                label: 'Email',
                icon: Icons.email,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              _buildPasswordField(
                controller: passwordController,
                label: 'Password',
                isObscured: _obscurePassword,
                onToggle:
                    () => setState(() => _obscurePassword = !_obscurePassword),
                isDark: isDark,
              ),
              SizedBox(height: 20),

              _buildPasswordField(
                controller: confirmPasswordController,
                label: 'Confirm Password',
                isObscured: _obscureConfirm,
                onToggle:
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
                isDark: isDark,
              ),
              SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    if (passwordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Passwords do not match"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final response = await ApiService.signup(
                      emailController.text.trim(),
                      passwordController.text.trim(),
                    );

                    final success = response.toLowerCase().contains("success");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success 
                          ? "You signed up successfully! Redirecting to login..." 
                          : response),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                    
                    if (success) {
                      Future.delayed(Duration(seconds: 2), () {
                        Navigator.pop(context);
                      });
                    }
                  }
                },

                child: Text(
                  "Sign Up",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isDark = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final themeColor = isDark ? Colors.white : Colors.black;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: themeColor),
      validator:
          validator ??
          (value) => value == null || value.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: themeColor),
        prefixIcon: Icon(icon, color: themeColor),
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
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    final themeColor = isDark ? Colors.white : Colors.black;

    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      style: TextStyle(color: themeColor),
      validator:
          (value) =>
              value == null || value.length < 6
                  ? 'Password must be at least 6 characters'
                  : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: themeColor),
        prefixIcon: Icon(Icons.lock, color: themeColor),
        filled: true,
        fillColor: isDark ? Colors.black26 : Colors.grey[200],
        suffixIcon: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder:
              (child, animation) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
          child: IconButton(
            key: ValueKey(isObscured),
            icon: Icon(
              isObscured ? Icons.visibility_off : Icons.visibility,
              color: themeColor,
            ),
            onPressed: onToggle,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: themeColor),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepPurple),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
