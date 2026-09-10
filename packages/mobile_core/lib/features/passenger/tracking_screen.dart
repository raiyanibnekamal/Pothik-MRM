import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/location/route_service.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/sos/sos_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:mobile_core/core/widgets/location_widgets.dart';
import 'package:mobile_core/core/widgets/sos_widgets.dart';
import 'package:mobile_core/features/shared/rating_sheet.dart';
import 'package:mobile_core/features/sos/sos_flow.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _edu = true;
  List<LatLng> _route = const [];
  bool _routeSnapped = true;
  String _routeKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ride = context.read<RideCubit>().state;
      if (ride.showDriverSheet) _showFound();
      _syncRoute();
    });
  }

  /// Before pickup the useful line is driver to rider; after that it is the
  /// trip itself.
  Future<void> _syncRoute() async {
    final state = context.read<RideCubit>().state;
    final ride = state.ride;
    if (ride == null) return;

    final started = ride.status == RideStatus.inProgress;
    final from = started ? ride.pickup : (ride.driverPoint ?? ride.pickup);
    final to = started ? ride.drop : ride.pickup;

    final key = '$started|$from|$to';
    if (key == _routeKey) return;
    _routeKey = key;

    if (!started && ride.driverPoint == null) {
      // Nothing to trace yet, so show the whole trip instead.
      final path = await context.read<RouteService>().driving(ride.pickup, ride.drop);
      if (!mounted) return;
      setState(() {
        _route = path.points;
        _routeSnapped = path.snapped;
      });
      return;
    }

    final path = await context.read<RouteService>().driving(from, to);
    if (!mounted) return;
    setState(() {
      _route = path.points;
      _routeSnapped = path.snapped;
    });
  }

  Future<void> _showFound() async {
    final cubit = context.read<RideCubit>();
    await showAppSheet<void>(
      context: context,
      isDismissible: false,
      child: _DriverFoundBody(
        ride: cubit.state.ride!,
        onContinue: () {
          Navigator.pop(context);
          cubit.ackDriverSheet();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final rideState = context.watch<RideCubit>().state;
    final ride = rideState.ride;
    final sos = context.watch<SosCubit>().state;
    final live = context.watch<LocationCubit>().state;
    if (ride == null) {
      return const SizedBox.shrink();
    }
    final inTrip = ride.status == RideStatus.inProgress ||
        ride.status == RideStatus.driverArriving ||
        ride.status == RideStatus.accepted ||
        ride.status == RideStatus.driverArrived;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRoute();
    });

    return Scaffold(
      body: Stack(
        children: [
          BrandedMap(
            center: ride.pickup,
            route: _route,
            routeSnapped: _routeSnapped,
            fitPoints: [
              ride.pickup,
              ride.drop,
              if (ride.driverPoint != null) ride.driverPoint!,
            ],
            showRecenter: true,
            overlayPadding: const EdgeInsets.only(bottom: 300),
            markers: [
              MapMarkerData(point: ride.pickup, kind: MapPinKind.pickup),
              MapMarkerData(point: ride.drop, kind: MapPinKind.drop),
              if (ride.driverPoint != null)
                MapMarkerData(point: ride.driverPoint!, kind: MapPinKind.driver),
              if (sos.active)
                MapMarkerData(
                  point: live.point ?? ride.pickup,
                  kind: MapPinKind.sos,
                ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: LocationHealthCard(compact: true),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inTrip)
                  Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SosHoldFab(
                        label: s.sos,
                        onConfirmed: () => context.go('/passenger/sos-countdown'),
                      ),
                    ),
                  ),
                Material(
                  color: AppColors.surface,
                  borderRadius: AppRadius.sheetTop,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.borderStrong,
                              borderRadius: AppRadius.smAll,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (ride.driver != null) _miniDriver(s, ride),
                        const SizedBox(height: 12),
                        Text(s.pinTellDriver, style: AppText.helper()),
                        Text(ride.pin, style: AppText.heroNumber()),
                        if (_edu) ...[
                          const SizedBox(height: 8),
                          Text(s.firstTripPin, style: AppText.helper()),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: s.call,
                                variant: AppButtonVariant.secondary,
                                onPressed: ride.driver?.phone == null
                                    ? null
                                    : () => launchUrl(
                                          Uri.parse('tel:${ride.driver!.phone}'),
                                        ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppButton(
                                label: s.shareTrip,
                                variant: AppButtonVariant.secondary,
                                onPressed: () => SharePlus.instance.share(
                                  ShareParams(text: ride.shareUrl ?? ''),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: s.safetyToolkit,
                          variant: AppButtonVariant.text,
                          onPressed: () => showSafetyToolkit(context, ride),
                        ),
                        if (ride.status != RideStatus.inProgress)
                          AppButton(
                            label: s.isBn ? 'ট্রিপ শুরু (ডেমো)' : 'Start trip (demo)',
                            onPressed: () {
                              setState(() => _edu = false);
                              context.read<RideCubit>().markInProgress();
                            },
                          )
                        else
                          AppButton(
                            label: s.tripComplete,
                            onPressed: () async {
                              await context.read<RideCubit>().complete();
                              if (!context.mounted) return;
                              await showCompleteAndRate(context);
                            },
                          ),
                        AppButton(
                          label: s.cancelRide,
                          variant: AppButtonVariant.text,
                          onPressed: () => _cancel(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDriver(S s, Ride ride) {
    final d = ride.driver!;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.navy50,
          child: Icon(PhosphorIconsRegular.user, color: AppColors.navy900),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(d.name, style: AppText.label())),
                  if (d.isVerified) ...[
                    const SizedBox(width: 8),
                    AppBadge(
                      label: s.verified,
                      tone: BadgeTone.success,
                      icon: PhosphorIconsFill.sealCheck,
                    ),
                  ],
                ],
              ),
              Text(
                '${d.rating} · ${d.vehicleModel} · ${d.color}',
                style: AppText.helper(),
              ),
              Text(d.plate, style: AppText.fare()),
              Text(s.matchPlate, style: AppText.caption()),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final s = S.of(context);
    final reason = await showAppSheet<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.cancelReasonTitle, style: AppText.title()),
            const SizedBox(height: 12),
            for (final r in [s.reasonWait, s.reasonWrong, s.reasonPlan, s.reasonOther])
              ListTile(
                title: Text(r, style: AppText.label()),
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
    if (reason != null && context.mounted) {
      await context.read<RideCubit>().cancel();
      if (context.mounted) context.go('/passenger/home');
    }
  }
}

class _DriverFoundBody extends StatelessWidget {
  const _DriverFoundBody({required this.ride, required this.onContinue});
  final Ride ride;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = ride.driver!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.driverFound, style: AppText.title()),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.navy50,
                child: Icon(PhosphorIconsRegular.user, color: AppColors.navy900),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: AppText.label()),
                    Text('${d.rating} · ${d.tripCount}', style: AppText.helper()),
                    if (d.isVerified)
                      AppBadge(
                        label: s.verified,
                        tone: BadgeTone.success,
                        icon: PhosphorIconsFill.sealCheck,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(d.plate, style: AppText.fare()),
          Text('${d.vehicleModel} · ${d.color}', style: AppText.helper()),
          Text(s.etaMin(d.etaMin), style: AppText.body()),
          const SizedBox(height: 16),
          AppButton(label: s.continueCta, onPressed: onContinue),
        ],
      ),
    );
  }
}

Future<void> showCompleteAndRate(BuildContext context) async {
  final s = S.of(context);
  final ride = context.read<RideCubit>().state.ride;
  if (ride == null) return;
  await showAppSheet<void>(
    context: context,
    isDismissible: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.tripComplete, style: AppText.title()),
          const SizedBox(height: 8),
          Text(s.payDriver(formatTaka(ride.fare.total)), style: AppText.heroNumber()),
          const SizedBox(height: 8),
          Text(s.exactCashNudge(formatTaka(ride.fare.total)), style: AppText.helper()),
          const SizedBox(height: 16),
          _row(s.base, formatTaka(ride.fare.base)),
          _row(s.distance, formatTaka(ride.fare.distance)),
          _row(s.time, formatTaka(ride.fare.time)),
          const SizedBox(height: 16),
          AppButton(
            label: s.continueCta,
            onPressed: () async {
              Navigator.pop(context);
              await showRatingSheet(context, onSubmit: () async {
                await context.read<RideCubit>().rateAndReset();
                if (context.mounted) context.go('/passenger/home');
              });
            },
          ),
        ],
      ),
    ),
  );
}

Widget _row(String k, String v) {
  return Row(
    children: [
      Expanded(child: Text(k, style: AppText.helper())),
      Text(v, style: AppText.fare()),
    ],
  );
}
