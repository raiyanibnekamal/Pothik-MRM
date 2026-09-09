import 'package:flutter/material.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_text.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.splash,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.brand,
              style: AppText.title(AppColors.interactiveAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'BD Ride Share',
              style: AppText.helper(AppColors.navy200),
            ),
          ],
        ),
      ),
    );
  }
}
