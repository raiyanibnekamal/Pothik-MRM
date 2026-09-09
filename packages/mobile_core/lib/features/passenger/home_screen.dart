import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ride = context.watch<RideCubit>().state;
    return Scaffold(
      body: Stack(
        children: [
          BrandedMap(
            center: ride.pickup,
            markers: [
              MapMarkerData(point: ride.pickup, kind: MapPinKind.me),
              if (ride.drop != null)
                MapMarkerData(point: ride.drop!, kind: MapPinKind.drop),
            ],
            onTap: (p) {
              context.read<RideCubit>().setDrop(p, s.isBn ? 'ম্যাপ পিন' : 'Dropped pin');
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _roundBtn(
                    icon: PhosphorIconsBold.user,
                    label: s.profile,
                    onTap: () => context.push('/passenger/profile'),
                  ),
                  const Spacer(),
                  _roundBtn(
                    icon: PhosphorIconsBold.clockCounterClockwise,
                    label: s.history,
                    onTap: () => context.push('/passenger/history'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdAll,
                      child: InkWell(
                        borderRadius: AppRadius.mdAll,
                        onTap: () => context.push('/passenger/search'),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.mdAll,
                            border: Border.all(color: AppColors.borderDefault),
                            boxShadow: AppShadows.sm,
                          ),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsBold.magnifyingGlass,
                                  color: AppColors.navy900),
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
                    Builder(
                      builder: (context) {
                        final recents = context.read<RideCubit>().backend.history;
                        if (recents.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: recents.length.clamp(0, 3),
                              separatorBuilder: (_, _) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final r = recents[i];
                                return Material(
                                  color: AppColors.surface,
                                  borderRadius: AppRadius.mdAll,
                                  child: InkWell(
                                    borderRadius: AppRadius.mdAll,
                                    onTap: () {
                                      context.read<RideCubit>().setDrop(r.drop, r.dropLabel);
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: AppRadius.mdAll,
                                        border: Border.all(color: AppColors.borderDefault),
                                      ),
                                      child: Text(r.dropLabel, style: AppText.label()),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    if (ride.drop != null) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: s.compareTitle,
                        onPressed: () => showRideOptions(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  final _places = const [
    ('Gulshan 1', LatLng(23.7806, 90.4193)),
    ('Banani', LatLng(23.7937, 90.4066)),
    ('Dhanmondi 27', LatLng(23.7465, 90.3760)),
    ('Motijheel', LatLng(23.7330, 90.4172)),
    ('Uttara Sector 7', LatLng(23.8740, 90.4000)),
    ('Farmgate', LatLng(23.7580, 90.3900)),
    ('Mirpur 10', LatLng(23.8070, 90.3680)),
    ('Airport', LatLng(23.8433, 90.3978)),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = _c.text.toLowerCase();
    final filtered = _places
        .where((p) => q.isEmpty || p.$1.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBarBack(title: s.whereTo),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _c,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: AppText.body(),
              decoration: InputDecoration(
                hintText: s.searchHint,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: const BorderSide(color: AppColors.borderStrong),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(s.recents, style: AppText.helper()),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in filtered)
                  ListTile(
                    leading: const Icon(PhosphorIconsRegular.mapPin,
                        color: AppColors.navy900),
                    title: Text(p.$1, style: AppText.label()),
                    minVerticalPadding: 16,
                    onTap: () {
                      context.read<RideCubit>().setDrop(p.$2, p.$1);
                      context.pop();
                      showRideOptions(context);
                    },
                  ),
              ],
            ),
          ),
        ],
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
                AppButton(
                  label: s.bookRide,
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
    return Material(
      color: selected ? AppColors.navy50 : AppColors.surface,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? AppColors.navy900 : AppColors.borderDefault,
            ),
          ),
          child: Row(
            children: [
              Icon(
                type.code == 'BIKE'
                    ? PhosphorIconsRegular.motorcycle
                    : PhosphorIconsRegular.car,
                color: AppColors.navy900,
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
      ),
    );
  }
}
