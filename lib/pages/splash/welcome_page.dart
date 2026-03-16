import 'package:flutter/material.dart';
import 'package:tindak/core/app_colors.dart';
import 'package:tindak/core/app_text_styles.dart';
import 'package:tindak/pages/auth/login_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void _onRideNowPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                /// Logo Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "tindak",
                      style: AppTextStyles.brandTitle,
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.pedal_bike,
                      color: AppColors.primaryGreen,
                      size: 34,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text(
                  "New riders: By continuing and signing up for an account, you confirm that you agree to Tindak’s User Agreement, and acknowledge that you have read Tindak’s Privacy Notice.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.description,
                ),

                const SizedBox(height: 60),

                /// Ride Now Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _onRideNowPressed(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Ride Now",
                      style: AppTextStyles.buttonText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}