import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/core/ride/ride_cubit.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/pressable.dart';
import 'package:mobile_core/features/passenger/finding_history.dart';
import 'package:mobile_core/features/passenger/home_screen.dart';
import 'package:mobile_core/features/passenger/passenger_shared.dart';
import 'package:mobile_core/features/profile/profile_screens.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class PassengerShell extends StatefulWidget {
  const PassengerShell({super.key});

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  int _tab = 0;
  bool _welcomeSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = context.read<RideCubit>().backend.history;
      if (!_welcomeSeen && history.isEmpty && mounted) {
        setState(() => _welcomeSeen = true);
        _showWelcome();
      }
    });
  }

  Future<void> _showWelcome() async {
    final s = S.of(context);
    await showAppSheet<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                gradient: const LinearGradient(
                  colors: [AppColors.navy800, AppColors.navy500, AppColors.amber400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: VectorPulse(
                  child: Icon(
                    PhosphorIconsFill.car,
                    size: 64,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.welcomeTitle, style: AppText.title()),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.welcomeBody, style: AppText.body(AppColors.textSecondary)),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: s.welcomeYes,
              onPressed: () {
                Navigator.pop(context);
                context.push('/passenger/search');
              },
            ),
            const SizedBox(height: 8),
            AppButton(
              label: s.welcomeNo,
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pages = [
      PassengerHomeTab(onOpenServices: () => setState(() => _tab = 1)),
      const ServicesTab(),
      const ActivityTab(),
      const AccountTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.sm,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              _NavItem(
                icon: PhosphorIconsRegular.house,
                activeIcon: PhosphorIconsFill.house,
                label: s.navHome,
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _NavItem(
                icon: PhosphorIconsRegular.squaresFour,
                activeIcon: PhosphorIconsFill.squaresFour,
                label: s.navServices,
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
              _NavItem(
                icon: PhosphorIconsRegular.receipt,
                activeIcon: PhosphorIconsFill.receipt,
                label: s.navActivity,
                selected: _tab == 2,
                onTap: () => setState(() => _tab = 2),
              ),
              _NavItem(
                icon: PhosphorIconsRegular.user,
                activeIcon: PhosphorIconsFill.user,
                label: s.navAccount,
                selected: _tab == 3,
                onTap: () => setState(() => _tab = 3),
                badge: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: Pressable.duration,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: Pressable.duration,
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navy50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      selected ? activeIcon : icon,
                      size: 22,
                      color: AppColors.navy900,
                    ),
                  ),
                  if (badge)
                    Positioned(
                      right: 6,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.interactiveAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppText.caption(
                  selected ? AppColors.navy900 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const LocationShareBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.servicesTitle, style: AppText.title()),
                  const SizedBox(height: 4),
                  Text(s.servicesSubtitle, style: AppText.body(AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceTile(
                          label: s.reserve,
                          icon: PhosphorIconsFill.calendarBlank,
                          pulse: true,
                          onTap: () => showScheduleSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ServiceTile(
                          label: s.trip,
                          icon: PhosphorIconsFill.car,
                          pulse: true,
                          onTap: () => context.push('/passenger/search'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceTile(
                          label: s.bike,
                          icon: PhosphorIconsFill.motorcycle,
                          onTap: () {
                            context.read<RideCubit>().selectType(MockBackend.bike);
                            context.push('/passenger/search');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ServiceTile(
                          label: s.car,
                          icon: PhosphorIconsFill.carProfile,
                          onTap: () {
                            context.read<RideCubit>().selectType(MockBackend.car);
                            context.push('/passenger/search');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.pulse = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy50,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VectorPulse(
              enabled: pulse,
              child: Icon(icon, size: 36, color: AppColors.navy900),
            ),
            const Spacer(),
            Text(label, style: AppText.label()),
          ],
        ),
      ),
    );
  }
}

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = context.watch<RideCubit>().backend.history;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const LocationShareBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.navActivity, style: AppText.title()),
                  const SizedBox(height: 24),
                  Text(s.upcoming, style: AppText.subhead()),
                  const SizedBox(height: 12),
                  Pressable(
                    onTap: () => showScheduleSheet(context),
                    borderRadius: AppRadius.mdAll,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.noUpcoming, style: AppText.label()),
                                const SizedBox(height: 8),
                                Text(
                                  s.reserveCta,
                                  style: AppText.label(AppColors.navy700),
                                ),
                              ],
                            ),
                          ),
                          const VectorPulse(
                            child: Icon(
                              PhosphorIconsFill.calendarBlank,
                              size: 40,
                              color: AppColors.interactiveAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: Text(s.past, style: AppText.subhead())),
                      Pressable(
                        onTap: () => context.push('/passenger/history'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.navy50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIconsBold.funnelSimple,
                            size: 18,
                            color: AppColors.navy900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Text(s.noPast, style: AppText.body(AppColors.textSecondary))
                  else
                    ...items.take(5).map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Pressable(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailScreen(ride: r),
                            ),
                          ),
                          borderRadius: AppRadius.mdAll,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(color: AppColors.borderDefault),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  r.vehicleType.code == 'BIKE'
                                      ? PhosphorIconsRegular.motorcycle
                                      : PhosphorIconsRegular.car,
                                  color: AppColors.navy900,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.dropLabel, style: AppText.label()),
                                      Text(
                                        r.pickupLabel,
                                        style: AppText.helper(),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(formatTaka(r.fare.total), style: AppText.fare()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<SessionCubit>().state.user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const LocationShareBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? s.profile, style: AppText.title()),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  PhosphorIconsFill.star,
                                  size: 16,
                                  color: AppColors.navy900,
                                ),
                                const SizedBox(width: 4),
                                Text('5.0', style: AppText.label()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.navy50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsFill.user,
                          size: 32,
                          color: AppColors.navy900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickCard(
                          icon: PhosphorIconsRegular.lifebuoy,
                          label: s.help,
                          onTap: () => showAppSnack(context, s.help),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickCard(
                          icon: PhosphorIconsRegular.wallet,
                          label: s.wallet,
                          onTap: () => showAppSnack(context, s.cashOnlyNote),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickCard(
                          icon: PhosphorIconsRegular.shieldCheck,
                          label: s.safety,
                          onTap: () => context.push('/passenger/safety'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickCard(
                          icon: PhosphorIconsRegular.envelopeSimple,
                          label: s.inbox,
                          badge: true,
                          onTap: () => showAppSnack(context, s.inbox),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AccountRow(
                    icon: PhosphorIconsRegular.usersThree,
                    title: s.contacts,
                    subtitle: s.emergencyContactsBody,
                    onTap: () => context.push('/passenger/guardians'),
                  ),
                  _AccountRow(
                    icon: PhosphorIconsRegular.gearSix,
                    title: s.settings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  _AccountRow(
                    icon: PhosphorIconsRegular.userCircle,
                    title: s.manageAccount,
                    subtitle: user?.phone,
                    onTap: () => context.push('/passenger/profile'),
                  ),
                  _AccountRow(
                    icon: PhosphorIconsRegular.info,
                    title: s.legal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalScreen()),
                    ),
                  ),
                  _AccountRow(
                    icon: PhosphorIconsRegular.signOut,
                    title: s.logout,
                    danger: true,
                    onTap: () => context.read<SessionCubit>().logout(),
                  ),
                  const SizedBox(height: 16),
                  Text('v1.0.0', style: AppText.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: 88,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navy50,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: AppColors.navy900, size: 22),
                if (badge)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.interactiveAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(label, style: AppText.caption(AppColors.navy900)),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger ? AppColors.danger : AppColors.navy900,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.label(danger ? AppColors.danger : null),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.helper()),
                  ],
                ],
              ),
            ),
            if (!danger)
              const Icon(
                PhosphorIconsBold.caretRight,
                size: 16,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class SafetyHubScreen extends StatelessWidget {
  const SafetyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: Pressable(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(20),
          child: const Icon(PhosphorIconsBold.x, color: AppColors.navy900),
        ),
        title: Text(s.safetyHub, style: AppText.title()),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.safetyPrefs, style: AppText.subhead()),
          const SizedBox(height: 4),
          Text(s.safetyPrefsBody, style: AppText.helper()),
          const SizedBox(height: 16),
          _SafetyRow(
            icon: PhosphorIconsRegular.gridNine,
            title: s.pinVerification,
            body: s.pinVerificationBody,
            active: true,
            onTap: () => showAppSnack(context, s.pinTellDriver),
          ),
          _SafetyRow(
            icon: PhosphorIconsRegular.userFocus,
            title: s.emergencyContacts,
            body: s.emergencyContactsBody,
            active: true,
            onTap: () => context.push('/passenger/guardians'),
          ),
          _SafetyRow(
            icon: PhosphorIconsRegular.broadcast,
            title: s.shareTripLoc,
            body: s.shareTripLocBody,
            active: true,
            onTap: () => showAppSnack(context, s.shareTrip),
          ),
          const SizedBox(height: 24),
          Text(s.safetyToolkit, style: AppText.subhead()),
          const SizedBox(height: 12),
          _SafetyRow(
            icon: PhosphorIconsRegular.shieldCheck,
            title: s.sos,
            body: s.sosHoldHint,
            onTap: () => context.push('/passenger/sos-countdown'),
          ),
          _SafetyRow(
            icon: PhosphorIconsRegular.phoneCall,
            title: s.call999,
            body: s.policePacket,
            onTap: () => showAppSnack(context, s.policeCopy),
          ),
        ],
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy900, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.label()),
                  const SizedBox(height: 2),
                  Text(body, style: AppText.helper()),
                ],
              ),
            ),
            if (active)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.interactiveAccent,
                  shape: BoxShape.circle,
                ),
              )
            else
              const Icon(
                PhosphorIconsBold.caretRight,
                size: 16,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
