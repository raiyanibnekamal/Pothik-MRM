import 'package:flutter/material.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Center(
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.forceUpdateTitle, style: AppText.title()),
                const SizedBox(height: 12),
                Text(s.forceUpdateBody, style: AppText.body()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
