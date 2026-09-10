import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/geo_service.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:mobile_core/core/widgets/location_widgets.dart';
import 'package:mobile_core/core/widgets/pressable.dart';
import 'package:mobile_core/features/passenger/map_pick_screen.dart';
import 'package:mobile_core/features/passenger/passenger_shared.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Uber-style home feed: Where to, Later, For you (Bike/Car), recents.
class PassengerHomeTab extends StatelessWidget {
  const PassengerHomeTab({super.key, this.onOpenServices});

  final VoidCallback? onOpenServices;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ride = context.watch<RideCubit>().state;
    final recents = context.read<RideCubit>().backend.history;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const LocationShareBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Center(child: Text(s.brand, style: AppText.title())),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LocationHealthCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _HomeMapPreview(
                pickup: ride.pickup,
                pickupLabel:
                    ride.pickupLabel.isEmpty ? s.currentLocation : ride.pickupLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => context.push('/passenger/search'),
                      borderRadius: AppRadius.mdAll,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.mdAll,
                          boxShadow: AppShadows.sm,
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsBold.magnifyingGlass,
                              color: AppColors.navy900,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ride.dropLabel ?? s.whereTo,
                                style: AppText.label(
                                  ride.dropLabel == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: () => showScheduleSheet(context),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.navy50,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.calendarBlank,
                            size: 18,
                            color: AppColors.navy900,
                          ),
                          const SizedBox(width: 6),
                          Text(s.later, style: AppText.label()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (recents.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...recents.take(2).map(
                (r) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Pressable(
                    onTap: () {
                      context.read<RideCubit>().setDrop(r.drop, r.dropLabel);
                      showRideOptions(context);
                    },
                    borderRadius: AppRadius.mdAll,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.clockCounterClockwise,
                            color: AppColors.navy900,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.dropLabel, style: AppText.label()),
                                Text(r.pickupLabel, style: AppText.helper()),
                              ],
                            ),
                          ),
                          const Icon(
                            PhosphorIconsBold.caretRight,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text(s.forYou, style: AppText.subhead())),
                  Pressable(
                    onTap: onOpenServices,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.navy50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsBold.arrowRight,
                        size: 16,
                        color: AppColors.navy900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ForYouChip(
                    label: s.trip,
                    icon: PhosphorIconsFill.car,
                    onTap: () => context.push('/passenger/search'),
                  ),
                  _ForYouChip(
                    label: s.bike,
                    icon: PhosphorIconsFill.motorcycle,
                    onTap: () {
                      context.read<RideCubit>().selectType(MockBackend.bike);
                      context.push('/passenger/search');
                    },
                  ),
                  _ForYouChip(
                    label: s.car,
                    icon: PhosphorIconsFill.carProfile,
                    onTap: () {
                      context.read<RideCubit>().selectType(MockBackend.car);
                      context.push('/passenger/search');
                    },
                  ),
                  _ForYouChip(
                    label: s.reserve,
                    icon: PhosphorIconsFill.calendarBlank,
                    onTap: () => showScheduleSheet(context),
                  ),
                ],
              ),
            ),
            if (ride.drop != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: AppButton(
                  label: s.compareTitle,
                  trailing: const Icon(
                    PhosphorIconsBold.arrowRight,
                    size: 18,
                    color: AppColors.textOnAccent,
                  ),
                  onPressed: () => showRideOptions(context),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Live map card on the home feed. Non-interactive so the feed still scrolls;
/// tapping opens the full picker.
class _HomeMapPreview extends StatelessWidget {
  const _HomeMapPreview({required this.pickup, required this.pickupLabel});

  final LatLng pickup;
  final String pickupLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () async {
        final cubit = context.read<RideCubit>();
        final picked = await showMapPicker(
          context,
          mode: MapPickMode.pickup,
          initial: pickup,
        );
        if (picked != null) cubit.setPickup(picked.point, picked.label);
      },
      borderRadius: AppRadius.mdAll,
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: SizedBox(
          height: 170,
          child: Stack(
            children: [
              Positioned.fill(
                child: BrandedMap(
                  center: pickup,
                  zoom: 15.5,
                  interactive: false,
                  markers: [
                    MapMarkerData(point: pickup, kind: MapPinKind.pickup),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.mdAll,
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.mapPin,
                        size: 16,
                        color: AppColors.pickupPin,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickupLabel,
                          style: AppText.label(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const LocationAccuracyChip(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForYouChip extends StatelessWidget {
  const _ForYouChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(48),
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              VectorPulse(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.navy50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: AppColors.navy900),
                ),
              ),
              const SizedBox(height: 8),
              Text(label, style: AppText.caption(AppColors.navy900)),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  Timer? _debounce;
  List<PlaceHit> _hits = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _hits = const [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    // Nominatim allows roughly one request per second.
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  Future<void> _search(String query) async {
    final hits = await context.read<GeoService>().search(query);
    if (!mounted || _c.text != query) return;
    setState(() {
      _hits = hits;
      _searching = false;
      _searched = true;
    });
  }

  void _choose(LatLng point, String label) {
    context.read<RideCubit>().setDrop(point, label);
    context.pop();
    showRideOptions(context);
  }

  Future<void> _pickOnMap() async {
    final ride = context.read<RideCubit>().state;
    final picked = await showMapPicker(
      context,
      mode: MapPickMode.drop,
      initial: ride.drop,
    );
    if (picked == null || !mounted) return;
    _choose(picked.point, picked.label);
  }

  Future<void> _editPickup() async {
    final ride = context.read<RideCubit>();
    final picked = await showMapPicker(
      context,
      mode: MapPickMode.pickup,
      initial: ride.state.pickup,
    );
    if (picked == null) return;
    ride.setPickup(picked.point, picked.label);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ride = context.watch<RideCubit>().state;
    final recents = context.read<RideCubit>().backend.history;

    return Scaffold(
      appBar: AppBarBack(title: s.whereTo),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _PickupRow(
              label: ride.pickupLabel.isEmpty ? s.currentLocation : ride.pickupLabel,
              onTap: _editPickup,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _c,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _search,
              style: AppText.body(),
              decoration: InputDecoration(
                hintText: s.searchHint,
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: const Icon(
                  PhosphorIconsBold.magnifyingGlass,
                  color: AppColors.navy900,
                ),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: const BorderSide(color: AppColors.borderStrong),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _SearchAction(
                  icon: PhosphorIconsFill.mapTrifold,
                  label: s.pickOnMap,
                  onTap: _pickOnMap,
                ),
                if (_hits.isNotEmpty) ...[
                  const Divider(height: 1),
                  for (final hit in _hits)
                    Pressable(
                      onTap: () => _choose(hit.point, hit.label),
                      child: ListTile(
                        leading: const Icon(
                          PhosphorIconsRegular.mapPin,
                          color: AppColors.navy900,
                        ),
                        title: Text(hit.label, style: AppText.label()),
                        subtitle: Text(hit.detail, style: AppText.helper()),
                        minVerticalPadding: 12,
                      ),
                    ),
                ] else if (_searched && !_searching)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(s.searchNoResults, style: AppText.helper()),
                  ),
                if (recents.isNotEmpty && _hits.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(s.recents, style: AppText.helper()),
                  ),
                  for (final r in recents.take(5))
                    Pressable(
                      onTap: () => _choose(r.drop, r.dropLabel),
                      child: ListTile(
                        leading: const Icon(
                          PhosphorIconsRegular.clockCounterClockwise,
                          color: AppColors.navy900,
                        ),
                        title: Text(r.dropLabel, style: AppText.label()),
                        subtitle: Text(r.pickupLabel, style: AppText.helper()),
                        minVerticalPadding: 12,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupRow extends StatelessWidget {
  const _PickupRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.navy50,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsFill.circlesThreePlus,
              size: 18,
              color: AppColors.pickupPin,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.pickupPointTitle, style: AppText.caption()),
                  Text(
                    label,
                    style: AppText.label(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.pencilSimple,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, color: AppColors.navy900),
        title: Text(label, style: AppText.label()),
        minVerticalPadding: 12,
      ),
    );
  }
}

Future<void> showRideOptions(BuildContext context) {
  final cubit = context.read<RideCubit>();
  return showAppSheet<void>(
    context: context,
    child: BlocProvider.value(
      value: cubit,
      child: const _RideOptionsBody(),
    ),
  );
}

class _RideOptionsBody extends StatelessWidget {
  const _RideOptionsBody();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = context.watch<RideCubit>().state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.compareTitle, style: AppText.title()),
          if (state.routeKm != null) ...[
            const SizedBox(height: 4),
            Text(
              s.routeSummary(
                state.routeKm!.toStringAsFixed(1),
                state.routeEtaMin ?? 0,
              ),
              style: AppText.helper(),
            ),
            if (!state.routeSnapped)
              Text(s.routeApprox, style: AppText.caption(AppColors.warning)),
          ],
          const SizedBox(height: 16),
          for (final t in state.types.where((t) => t.isActive))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TypeCard(
                type: t,
                selected: state.selectedType?.id == t.id,
                fare: context.read<RideCubit>().breakdownFor(t),
                onTap: () => context.read<RideCubit>().selectType(t),
              ),
            ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final t = state.selectedType;
            if (t == null) return const SizedBox.shrink();
            final fare = context.read<RideCubit>().breakdownFor(t);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.fareBreakdown, style: AppText.helper()),
                const SizedBox(height: 8),
                _row(s.base, formatTaka(fare.base)),
                _row(s.distance, formatTaka(fare.distance)),
                _row(s.time, formatTaka(fare.time)),
                _row(s.minFare, formatTaka(fare.minFare)),
                const SizedBox(height: 8),
                Text(
                  s.exactCashNudge(formatTaka(fare.total)),
                  style: AppText.helper(),
                ),
                const SizedBox(height: 8),
                AppBadge(label: s.cash, tone: BadgeTone.navy),
                const SizedBox(height: 16),
                Pressable(
                  onTap: () {},
                  borderRadius: AppRadius.mdAll,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy50,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsFill.money,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.cash, style: AppText.label())),
                        const Icon(
                          PhosphorIconsBold.caretRight,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: '${s.bookRide} · ${t.label(s.isBn)}',
                  loading: state.busy,
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<RideCubit>().book();
                    context.go('/passenger/finding');
                  },
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: AppText.helper())),
          Text(v, style: AppText.fare()),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.fare,
    required this.onTap,
  });

  final VehicleType type;
  final bool selected;
  final FareBreakdown fare;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: Pressable.duration,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy50 : AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.navy900 : AppColors.borderDefault,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            VectorPulse(
              enabled: selected,
              child: Icon(
                type.code == 'BIKE'
                    ? PhosphorIconsRegular.motorcycle
                    : PhosphorIconsRegular.car,
                color: AppColors.navy900,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label(s.isBn), style: AppText.label()),
                  Text(s.etaMin(type.etaMin), style: AppText.helper()),
                ],
              ),
            ),
            Text(formatTaka(fare.total), style: AppText.heroNumber()),
          ],
        ),
      ),
    );
  }
}
