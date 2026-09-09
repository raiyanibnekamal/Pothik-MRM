import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/driver/driver_session_cubit.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/sos/sos_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:mobile_core/core/widgets/sos_widgets.dart';
import 'package:mobile_core/features/shared/rating_sheet.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<SessionCubit>().state.user;
    final ds = context.watch<DriverSessionCubit>().state;
    return Scaffold(
      body: Stack(
        children: [
          const BrandedMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.interactivePrimary,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: StatusDot(
                      online: ds.online && !ds.onBreak,
                      label: ds.onBreak
                          ? s.onBreak
                          : ds.online
                              ? s.online
                              : s.offlineStatus,
                    ),
                  ),
                  const Spacer(),
                  _iconBtn(
                    PhosphorIconsBold.wallet,
                    s.earnings,
                    () => context.push('/driver/earnings'),
                  ),
                  const SizedBox(width: 8),
                  _iconBtn(
                    PhosphorIconsBold.user,
                    s.profile,
                    () => context.push('/driver/profile'),
                  ),
                ],
              ),
            ),
          ),
          if (ds.phase == DriverTripPhase.request && ds.request != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(child: _RequestCard(request: ds.request!)),
            )
          else if (ds.phase != DriverTripPhase.idle)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(child: _TripCard(state: ds)),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user?.commissionDebtBdt != null &&
                          (user!.commissionDebtBdt > 0))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Text(
                              '${s.debtWarning}: ${formatTaka(user.commissionDebtBdt)}',
                              style: AppText.label(AppColors.warning),
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
                              err == 'DEBT_CAP' ? s.debtCap : s.graceOver,
                              error: true,
                            );
                          }
                        },
                      ),
                      if (ds.online)
                        AppButton(
                          label: s.onBreak,
                          variant: AppButtonVariant.text,
                          onPressed: () =>
                              context.read<DriverSessionCubit>().toggleBreak(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (ds.online)
            Positioned(
              right: 16,
              bottom: 120,
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

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.navy900, size: 20),
        ),
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheetTop,
        border: Border.all(color: AppColors.borderDefault),
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: switch (state.phase) {
        DriverTripPhase.toPickup => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: s.navPickup,
                variant: AppButtonVariant.secondary,
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=23.7925,90.4078&travelmode=driving',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(label: s.arrived, onPressed: cubit.arrived),
            ],
          ),
        DriverTripPhase.arrived => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.waitNoShow, style: AppText.subhead()),
              const SizedBox(height: 12),
              AppButton(label: s.enterPin, onPressed: cubit.openPin),
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
            children: [
              AppButton(
                label: s.navDrop,
                variant: AppButtonVariant.secondary,
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=23.7806,90.4193&travelmode=driving',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(label: s.completeTrip, onPressed: cubit.openCash),
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

class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final e = context.watch<DriverSessionCubit>().backend.earnings();
    return Scaffold(
      appBar: AppBarBack(title: s.earnings),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.today, style: AppText.helper()),
                  Text(formatTaka(e.net), style: AppText.heroNumber()),
                  const SizedBox(height: 16),
                  _row(s.gross, formatTaka(e.gross)),
                  _row(s.commission, formatTaka(e.commission)),
                  _row(s.net, formatTaka(e.net)),
                  _row(s.trips, '${e.trips}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Text(
                '${s.debtWarning}: ${formatTaka(e.debt)}',
                style: AppText.label(
                  e.debt > 0 ? AppColors.warning : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(k, style: AppText.helper())),
            Text(v, style: AppText.fare()),
          ],
        ),
      );
}

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saver = context.watch<DriverSessionCubit>().state.batterySaver;
    return Scaffold(
      appBar: AppBarBack(title: s.profile),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(s.batterySaver, style: AppText.label()),
            value: saver,
            activeThumbColor: AppColors.navy900,
            onChanged: (v) =>
                context.read<DriverSessionCubit>().setBatterySaver(v),
          ),
          ListTile(
            title: Text(s.language, style: AppText.label()),
            trailing: Text(s.isBn ? s.bangla : s.english, style: AppText.helper()),
            onTap: () => context.read<LocaleCubit>().toggle(),
          ),
          ListTile(
            title: Text(s.documentsTitle, style: AppText.label()),
            onTap: () {},
          ),
          ListTile(
            title: Text(s.logout, style: AppText.label(AppColors.danger)),
            onTap: () => context.read<SessionCubit>().logout(),
          ),
        ],
      ),
    );
  }
}
