import 'package:flutter/material.dart';
import 'package:tindak/core/app_colors.dart';
import 'package:tindak/core/app_text_styles.dart';
import 'package:tindak/pages/auth/signup_password_page.dart';

class SignUpEmailPage extends StatelessWidget {
  const SignUpEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            const Text(
              "What's your email?",
              style: AppTextStyles.brandTitle,
            ),

            const SizedBox(height: 40),

            TextField(
              controller: emailController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: "",
                border: UnderlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "Use your school or work e-mail to unlock offers.",
              style: AppTextStyles.description,
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignUpPasswordPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Next",
                  style: AppTextStyles.buttonText,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}