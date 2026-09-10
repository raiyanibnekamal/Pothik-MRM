import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/sos/sos_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:mobile_core/core/widgets/sos_widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showSafetyToolkit(BuildContext context, Ride ride) {
  final s = S.of(context);
  return showAppSheet<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.safetyToolkit, style: AppText.title()),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.shareTrip, style: AppText.label()),
            onTap: () => SharePlus.instance.share(
              ShareParams(text: ride.shareUrl ?? ''),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.call999, style: AppText.label(AppColors.danger)),
            subtitle: Text(s.policePacket, style: AppText.helper()),
            onTap: () => launchUrl(Uri.parse('tel:999')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.guardians, style: AppText.label()),
            onTap: () => context.push('/passenger/guardians'),
          ),
          Text(s.sosHoldHint, style: AppText.helper()),
        ],
      ),
    ),
  );
}

class SosCountdownScreen extends StatefulWidget {
  const SosCountdownScreen({super.key});

  @override
  State<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends State<SosCountdownScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    context.read<SosCubit>().beginCountdown();
    _t = Timer.periodic(const Duration(seconds: 1), (_) async {
      final cubit = context.read<SosCubit>();
      cubit.tick();
      if (cubit.state.secondsLeft <= 0) {
        _t?.cancel();
        final ride = context.read<RideCubit>().state.ride;
        await cubit.send(rideStatus: ride?.status, driverOnline: false);
        if (mounted) context.go('/passenger/sos-active');
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<SosCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.dangerBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(),
              CountdownRing(
                progress: st.secondsLeft / 5,
                size: 160,
                child: Text(
                  '${st.secondsLeft}',
                  style: AppText.heroNumber(AppColors.danger),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.sosCountdownHint(st.secondsLeft),
                style: AppText.body(),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: s.sosCancel,
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  _t?.cancel();
                  context.read<SosCubit>().abortCountdown();
                  context.go('/passenger/tracking');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SosActiveScreen extends StatelessWidget {
  const SosActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final alert = context.watch<SosCubit>().state.alert;
    final live = context.watch<LocationCubit>().state;
    return Scaffold(
      appBar: AppBarBack(
        title: s.sos,
        navy: true,
        onBack: () => context.go('/passenger/tracking'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: BrandedMap(
              center: live.point ?? dhakaCenter,
              zoom: 16.5,
              follow: true,
              showRecenter: true,
              markers: [
                if (live.point != null)
                  MapMarkerData(point: live.point!, kind: MapPinKind.sos),
              ],
            ),
          ),
          Expanded(
            child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBadge(label: 'SOS', tone: BadgeTone.danger),
            const SizedBox(height: 16),
            Text(s.sosActive, style: AppText.title()),
            const SizedBox(height: 8),
            if (live.point != null)
              Text(
                '${live.point!.latitude.toStringAsFixed(5)}, '
                '${live.point!.longitude.toStringAsFixed(5)}'
                '${live.accuracyM == null ? '' : ' · ${s.locationAccuracy(live.accuracyM!.round())}'}',
                style: AppText.helper(),
              )
            else
              Text(s.locationSearching, style: AppText.helper()),
            const SizedBox(height: 8),
            Text(alert?.trackUrl ?? '', style: AppText.helper()),
            const Spacer(),
            AppButton(
              label: s.call999,
              variant: AppButtonVariant.danger,
              onPressed: () => launchUrl(Uri.parse('tel:999')),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: s.shareTrip,
              variant: AppButtonVariant.secondary,
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: [
                    alert?.trackUrl ?? '',
                    if (live.point != null)
                      'https://maps.google.com/?q='
                          '${live.point!.latitude},${live.point!.longitude}',
                  ].where((t) => t.isNotEmpty).join('\n'),
                ),
              ),
            ),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}
