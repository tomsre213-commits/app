import 'package:flutter/material.dart';
import 'package:tindak/core/app_colors.dart';
import 'package:tindak/core/app_text_styles.dart';
import 'package:tindak/pages/auth/signup_email_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _onLoginPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login pressed")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Welcome Title
                const Text(
                  "Welcome",
                  style: AppTextStyles.brandTitle,
                ),

                const SizedBox(height: 8),

                /// Subtitle
                const Text(
                  "Sign in to continue",
                  style: AppTextStyles.description,
                ),

                const SizedBox(height: 40),

                /// Username field
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: "Username",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _onLoginPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Login",
                      style: AppTextStyles.buttonText,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Forgot Password?",
                  style: AppTextStyles.description,
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text(
                      "Don't have an account? ",
                      style: AppTextStyles.description,
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpEmailPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}