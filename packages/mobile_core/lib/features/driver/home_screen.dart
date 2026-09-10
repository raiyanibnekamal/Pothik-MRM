import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/driver/driver_session_cubit.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/sos/sos_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:mobile_core/core/widgets/pressable.dart';
import 'package:mobile_core/core/widgets/sos_widgets.dart';
import 'package:mobile_core/features/shared/rating_sheet.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Map-first driver home: status, earnings chip, online toggle, trip flow.
class DriverHomeTab extends StatelessWidget {
  const DriverHomeTab({super.key, this.onOpenEarnings});

  final VoidCallback? onOpenEarnings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<SessionCubit>().state.user;
    final ds = context.watch<DriverSessionCubit>().state;
    final earnings = ds.earnings ?? context.read<DriverSessionCubit>().backend.earnings();
    final immersive = ds.phase != DriverTripPhase.idle;
    final bottomInset = immersive ? 16.0 : 96.0;

    return Scaffold(
      body: Stack(
        children: [
          const BrandedMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _StatusBadge(
                        online: ds.online && !ds.onBreak,
                        onBreak: ds.onBreak,
                      ),
                      const Spacer(),
                      if (onOpenEarnings != null)
                        Pressable(
                          onTap: onOpenEarnings,
                          borderRadius: AppRadius.mdAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.mdAll,
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.borderDefault),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  PhosphorIconsFill.wallet,
                                  size: 16,
                                  color: AppColors.navy900,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.driverTodayChip(formatTaka(earnings.net)),
                                  style: AppText.label(),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (ds.phase == DriverTripPhase.request && ds.request != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: EdgeInsets.only(bottom: bottomInset),
                child: _RequestCard(request: ds.request!),
              ),
            )
          else if (ds.phase != DriverTripPhase.idle)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: EdgeInsets.only(bottom: bottomInset),
                child: _TripCard(state: ds),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: EdgeInsets.only(bottom: bottomInset),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user?.commissionDebtBdt != null &&
                          user!.commissionDebtBdt > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Row(
                              children: [
                                const Icon(
                                  PhosphorIconsFill.warning,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${s.debtWarning}: ${formatTaka(user.commissionDebtBdt)}',
                                    style: AppText.label(AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      AppButton(
                        label: ds.online ? s.goOffline : s.goOnline,
                        variant: ds.online
                            ? AppButtonVariant.secondary
                            : AppButtonVariant.primary,
                        height: 52,
                        onPressed: () async {
                          final cubit = context.read<DriverSessionCubit>();
                          if (ds.online) {
                            cubit.goOffline();
                            return;
                          }
                          final err = await cubit.goOnline(
                            debtBlocked: user?.debtBlocked ?? false,
                            graceBlocked: user?.onboarding ==
                                    DriverOnboardingStatus.grace
                                ? false
                                : (user?.graceExpired ?? false) &&
                                    user?.onboarding !=
                                        DriverOnboardingStatus.approved,
                          );
                          if (err != null && context.mounted) {
                            showAppSnack(
                              context,
                              err == ErrorCodes.debtCap ? s.debtCap : s.graceOver,
                              error: true,
                            );
                          }
                        },
                      ),
                      if (ds.online) ...[
                        const SizedBox(height: 8),
                        AppButton(
                          label: ds.onBreak ? s.driverEndBreak : s.onBreak,
                          variant: AppButtonVariant.text,
                          onPressed: () =>
                              context.read<DriverSessionCubit>().toggleBreak(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (ds.online && ds.phase == DriverTripPhase.idle)
            Positioned(
              right: 16,
              bottom: bottomInset + 88,
              child: SosHoldFab(
                label: s.sos,
                onConfirmed: () async {
                  await context.read<SosCubit>().send(
                        rideStatus: null,
                        driverOnline: true,
                      );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.online, required this.onBreak});

  final bool online;
  final bool onBreak;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = onBreak
        ? s.onBreak
        : online
            ? s.online
            : s.offlineStatus;
    final color = onBreak
        ? AppColors.warning
        : online
            ? AppColors.interactivePrimary
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppText.caption(color)),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final DriverRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ds = context.watch<DriverSessionCubit>().state;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheetTop,
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CountdownRing(
                progress: ds.requestLeft / 15,
                child: Text('${ds.requestLeft}', style: AppText.fare()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.requestNew, style: AppText.title()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(formatTaka(request.fareBdt), style: AppText.heroNumber()),
          Text('${s.dropArea}: ${request.dropArea}', style: AppText.body()),
          Text(
            '${request.pickupDistanceKm} km · ${request.paymentMethod}',
            style: AppText.helper(),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: s.accept,
            height: 52,
            onPressed: () => context.read<DriverSessionCubit>().accept(),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: s.decline,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.read<DriverSessionCubit>().decline(),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.state});
  final DriverSessionState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cubit = context.read<DriverSessionCubit>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: AppShadows.sm,
      ),
      child: switch (state.phase) {
        DriverTripPhase.toPickup => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.driverHeadingPickup, style: AppText.subhead()),
              const SizedBox(height: 12),
              AppButton(
                label: s.navPickup,
                variant: AppButtonVariant.secondary,
                height: 52,
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=23.7925,90.4078&travelmode=driving',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(label: s.arrived, height: 52, onPressed: cubit.arrived),
            ],
          ),
        DriverTripPhase.arrived => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.waitNoShow, style: AppText.subhead()),
              const SizedBox(height: 12),
              AppButton(label: s.enterPin, height: 52, onPressed: cubit.openPin),
              AppButton(
                label: s.noShow,
                variant: AppButtonVariant.text,
                onPressed: cubit.finishTrip,
              ),
            ],
          ),
        DriverTripPhase.pin => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.enterPin, style: AppText.title()),
              const SizedBox(height: 8),
              Text(s.firstTripPin, style: AppText.helper(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CodeBoxes(
                length: 4,
                error: state.pinError,
                shakeToken: state.pinError ? 1 : 0,
                onChanged: cubit.setPin,
                onCompleted: (_) {},
              ),
              const SizedBox(height: 16),
              AppButton(
                label: s.startTrip,
                height: 52,
                onPressed: state.pin.length == 4
                    ? () {
                        if (!cubit.submitPin()) {
                          showAppSnack(context, S.of(context).wrongOtp(1),
                              error: true);
                        }
                      }
                    : null,
              ),
            ],
          ),
        DriverTripPhase.toDrop => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.driverHeadingDrop, style: AppText.subhead()),
              const SizedBox(height: 12),
              AppButton(
                label: s.navDrop,
                variant: AppButtonVariant.secondary,
                height: 52,
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=23.7806,90.4193&travelmode=driving',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: s.completeTrip,
                height: 52,
                onPressed: cubit.openCash,
              ),
            ],
          ),
        DriverTripPhase.cash => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatTaka(state.fareBdt == 0 ? 250 : state.fareBdt),
                  style: AppText.heroNumber()),
              const SizedBox(height: 8),
              Text(
                s.exactCashNudge(
                  formatTaka(state.fareBdt == 0 ? 250 : state.fareBdt),
                ),
                style: AppText.helper(),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: s.cashReceived,
                height: 52,
                loading: state.busy,
                onPressed: cubit.confirmCash,
              ),
            ],
          ),
        DriverTripPhase.rate => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.rateTitle, style: AppText.title()),
              const SizedBox(height: 12),
              AppButton(
                label: s.submit,
                height: 52,
                onPressed: () async {
                  await showRatingSheet(
                    context,
                    onSubmit: () async {
                      cubit.finishTrip();
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
