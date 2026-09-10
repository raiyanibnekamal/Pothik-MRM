import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/route_service.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class FindingDriverScreen extends StatelessWidget {
  const FindingDriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return BlocListener<RideCubit, RideState>(
      listenWhen: (p, c) => p.phase != c.phase,
      listener: (context, state) {
        if (state.phase == RidePhase.matched ||
            state.phase == RidePhase.tracking) {
          context.go('/passenger/tracking');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: BlocBuilder<RideCubit, RideState>(
              builder: (context, state) {
                if (state.phase == RidePhase.noDriver) {
                  return EmptyState(
                    title: s.noDrivers,
                    body: s.findingHint,
                    cta: s.tryAgain,
                    onCta: () {
                      context.read<RideCubit>().retryFind();
                    },
                    icon: PhosphorIconsRegular.car,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.findingDriver, style: AppText.title()),
                    const SizedBox(height: 8),
                    Text(s.findingHint, style: AppText.body(AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: AppRadius.mdAll,
                      child: SizedBox(
                        height: 200,
                        child: BrandedMap(
                          center: state.pickup,
                          interactive: false,
                          route: state.routePoints,
                          routeSnapped: state.routeSnapped,
                          fitPoints: [
                            state.pickup,
                            if (state.drop != null) state.drop!,
                          ],
                          markers: [
                            MapMarkerData(
                              point: state.pickup,
                              kind: MapPinKind.pickup,
                            ),
                            if (state.drop != null)
                              MapMarkerData(
                                point: state.drop!,
                                kind: MapPinKind.drop,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.routeKm != null)
                      Text(
                        s.routeSummary(
                          state.routeKm!.toStringAsFixed(1),
                          state.routeEtaMin ?? 0,
                        ),
                        style: AppText.helper(),
                      ),
                    const Spacer(),
                    AppButton(
                      label: s.cancelRide,
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        await context.read<RideCubit>().cancel();
                        if (context.mounted) context.go('/passenger/home');
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = context.read<RideCubit>().backend.history;
    return Scaffold(
      appBar: AppBarBack(title: s.history),
      body: items.isEmpty
          ? EmptyState(
              title: s.emptyHistory,
              body: s.recents,
              cta: s.emptyHistoryCta,
              onCta: () => context.go('/passenger/home'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = items[i];
                return AppCard(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailScreen(ride: r),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.dropLabel, style: AppText.label()),
                        const SizedBox(height: 4),
                        Text(formatTaka(r.fare.total), style: AppText.fare()),
                        Text(r.vehicleType.label(s.isBn), style: AppText.helper()),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.ride});
  final Ride ride;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<LatLng> _route = const [];
  bool _snapped = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  Future<void> _loadRoute() async {
    final path = await context
        .read<RouteService>()
        .driving(widget.ride.pickup, widget.ride.drop);
    if (!mounted) return;
    setState(() {
      _route = path.points;
      _snapped = path.snapped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return Scaffold(
      appBar: AppBarBack(title: ride.dropLabel),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: BrandedMap(
              interactive: false,
              showMe: false,
              route: _route,
              routeSnapped: _snapped,
              fitPoints: [ride.pickup, ride.drop],
              markers: [
                MapMarkerData(point: ride.pickup, kind: MapPinKind.pickup),
                MapMarkerData(point: ride.drop, kind: MapPinKind.drop),
              ],
              center: ride.pickup,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatTaka(ride.fare.total), style: AppText.heroNumber()),
                  const SizedBox(height: 8),
                  Text('${ride.pickupLabel} → ${ride.dropLabel}',
                      style: AppText.body()),
                  Text('#${ride.id}', style: AppText.helper()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
