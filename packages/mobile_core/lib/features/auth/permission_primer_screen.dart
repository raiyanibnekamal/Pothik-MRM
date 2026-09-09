import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class PermissionPrimerScreen extends StatelessWidget {
  const PermissionPrimerScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    await Geolocator.requestPermission();
    if (!context.mounted) return;
    await context.read<SessionCubit>().markLocationPrimed();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Icon(PhosphorIconsRegular.mapPin, size: 48, color: AppColors.navy900),
              const SizedBox(height: 24),
              Text(s.permissionTitle, style: AppText.title()),
              const SizedBox(height: 12),
              Text(s.permissionBody, style: AppText.body(AppColors.textSecondary)),
              const Spacer(),
              AppButton(label: s.allowLocation, onPressed: () => _continue(context)),
            ],
          ),
        ),
      ),
    );
  }
}
