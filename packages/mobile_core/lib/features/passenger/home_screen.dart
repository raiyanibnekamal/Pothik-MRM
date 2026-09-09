import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/pressable.dart';
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
                  Pressable(
                    onTap: () {
                      context.read<RideCubit>().setDrop(p.$2, p.$1);
                      context.pop();
                      showRideOptions(context);
                    },
                    child: ListTile(
                      leading: const Icon(
                        PhosphorIconsRegular.mapPin,
                        color: AppColors.navy900,
                      ),
                      title: Text(p.$1, style: AppText.label()),
                      minVerticalPadding: 16,
                    ),
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
