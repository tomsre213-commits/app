import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {

  // App brand title (tindak)
  static const TextStyle brandTitle = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryGreen,
    letterSpacing: 1.2,
  );

  // Description text
  static const TextStyle description = TextStyle(
    fontSize: 12,
    color: AppColors.textLight,
    height: 1.4,
  );

  // Button text style
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

}