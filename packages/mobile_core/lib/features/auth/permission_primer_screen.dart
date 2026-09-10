import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/location_widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class PermissionPrimerScreen extends StatefulWidget {
  const PermissionPrimerScreen({super.key});

  @override
  State<PermissionPrimerScreen> createState() => _PermissionPrimerScreenState();
}

class _PermissionPrimerScreenState extends State<PermissionPrimerScreen> {
  bool _busy = false;

  /// Asks the OS, then starts streaming so the first map already has a fix.
  Future<void> _continue() async {
    setState(() => _busy = true);
    final location = context.read<LocationCubit>();
    final granted = await location.ensure();
    if (granted) await location.startStream();
    if (!mounted) return;
    setState(() => _busy = false);
    await context.read<SessionCubit>().markLocationPrimed();
  }

  Future<void> _skip() async {
    await context.read<SessionCubit>().markLocationPrimed();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final live = context.watch<LocationCubit>().state;
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
              if (live.blocked) ...[
                const SizedBox(height: 20),
                const LocationHealthCard(),
              ],
              const Spacer(),
              AppButton(
                label: s.allowLocation,
                loading: _busy,
                onPressed: _continue,
              ),
              if (live.blocked)
                AppButton(
                  label: s.skip,
                  variant: AppButtonVariant.text,
                  onPressed: _skip,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
