import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/location_widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class PermissionPrimerScreen extends StatefulWidget {
  const PermissionPrimerScreen({super.key});

  @override
  State<PermissionPrimerScreen> createState() => _PermissionPrimerScreenState();
}

class _PermissionPrimerScreenState extends State<PermissionPrimerScreen> {
  bool _busy = false;

  Future<void> _advance({required bool askPermission}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final location = context.read<LocationCubit>();
      final session = context.read<SessionCubit>();
      if (askPermission) {
        // Do not wait for a GPS fix here — emulators can hang 20+ seconds.
        await location.ensure(request: true, requireFix: false);
        unawaited(location.startStream());
      }
      await session.markLocationPrimed();
      if (!mounted) return;
      context.go('/passenger/home');
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          S.of(context).isBn
              ? 'এগিয়ে যাওয়া যায়নি। আবার চেষ্টা করুন।'
              : 'Could not continue. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                onPressed: () => _advance(askPermission: true),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: s.skip,
                variant: AppButtonVariant.text,
                onPressed: _busy ? null : () => _advance(askPermission: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
