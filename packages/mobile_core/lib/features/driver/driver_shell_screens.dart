import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/driver/driver_session_cubit.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/pressable.dart';
import 'package:mobile_core/features/driver/home_screen.dart';
import 'package:mobile_core/features/passenger/finding_history.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _tab = 0;
  bool _welcomeSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_welcomeSeen && mounted) {
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
                  colors: [
                    AppColors.navy800,
                    AppColors.navy500,
                    AppColors.amber400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: VectorPulse(
                  child: Icon(
                    PhosphorIconsFill.steeringWheel,
                    size: 64,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.driverWelcomeTitle, style: AppText.title()),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.driverWelcomeBody,
                style: AppText.body(AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: s.driverWelcomeGo,
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
    final ds = context.watch<DriverSessionCubit>().state;
    final immersive = ds.phase != DriverTripPhase.idle;

    final pages = [
      DriverHomeTab(onOpenEarnings: () => setState(() => _tab = 1)),
      const DriverEarningsTab(),
      const DriverActivityTab(),
      const DriverAccountTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: immersive
          ? null
          : SafeArea(
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
                    _DriverNavItem(
                      icon: PhosphorIconsRegular.house,
                      activeIcon: PhosphorIconsFill.house,
                      label: s.navHome,
                      selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _DriverNavItem(
                      icon: PhosphorIconsRegular.wallet,
                      activeIcon: PhosphorIconsFill.wallet,
                      label: s.navEarnings,
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                    _DriverNavItem(
                      icon: PhosphorIconsRegular.receipt,
                      activeIcon: PhosphorIconsFill.receipt,
                      label: s.navActivity,
                      selected: _tab == 2,
                      onTap: () => setState(() => _tab = 2),
                    ),
                    _DriverNavItem(
                      icon: PhosphorIconsRegular.user,
                      activeIcon: PhosphorIconsFill.user,
                      label: s.navAccount,
                      selected: _tab == 3,
                      onTap: () => setState(() => _tab = 3),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DriverNavItem extends StatelessWidget {
  const _DriverNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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

class DriverEarningsTab extends StatelessWidget {
  const DriverEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final e = context.watch<DriverSessionCubit>().backend.earnings();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(s.earnings, style: AppText.title()),
            const SizedBox(height: 4),
            Text(s.driverEarningsSubtitle, style: AppText.body(AppColors.textSecondary)),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.today, style: AppText.helper()),
                  Text(formatTaka(e.net), style: AppText.heroNumber()),
                  const SizedBox(height: 16),
                  _EarningsRow(label: s.gross, value: formatTaka(e.gross)),
                  _EarningsRow(label: s.commission, value: formatTaka(e.commission)),
                  _EarningsRow(label: s.net, value: formatTaka(e.net)),
                  _EarningsRow(label: s.trips, value: '${e.trips}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsFill.warning,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
            const SizedBox(height: 20),
            Text(s.driverTipsTitle, style: AppText.subhead()),
            const SizedBox(height: 12),
            _TipTile(text: s.driverTip1),
            _TipTile(text: s.driverTip2),
            _TipTile(text: s.driverTip3),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.info, color: AppColors.navy700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.cashOnlyNote, style: AppText.helper()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.helper())),
          Text(value, style: AppText.fare()),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsFill.checkCircle,
            size: 18,
            color: AppColors.interactivePrimary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body())),
        ],
      ),
    );
  }
}

class DriverActivityTab extends StatelessWidget {
  const DriverActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = context.watch<DriverSessionCubit>().backend.history;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(s.navActivity, style: AppText.title()),
            const SizedBox(height: 4),
            Text(s.driverActivitySubtitle, style: AppText.body(AppColors.textSecondary)),
            const SizedBox(height: 20),
            if (items.isEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.emptyHistory, style: AppText.label()),
                    const SizedBox(height: 8),
                    Text(s.driverEmptyActivity, style: AppText.helper()),
                  ],
                ),
              )
            else
              ...items.map(
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
                                  '${s.pickupShort}: ${r.pickupLabel}',
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
    );
  }
}

class DriverAccountTab extends StatelessWidget {
  const DriverAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<SessionCubit>().state.user;
    final saver = context.watch<DriverSessionCubit>().state.batterySaver;
    final kycLabel = _kycLabel(s, user?.onboarding);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
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
                            PhosphorIconsFill.sealCheck,
                            size: 16,
                            color: AppColors.interactivePrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(kycLabel, style: AppText.label()),
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
                    onTap: () => showAppSnack(context, s.driverSupport),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: PhosphorIconsRegular.shieldCheck,
                    label: s.safety,
                    onTap: () => showAppSnack(context, s.policePacket),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: PhosphorIconsRegular.fileText,
                    label: s.documentsTitle,
                    onTap: () => context.push('/driver/documents'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(s.driverVehicleSection, style: AppText.subhead()),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VehicleRow(icon: PhosphorIconsFill.car, label: s.vehicleType, value: 'Bike'),
                  _VehicleRow(icon: PhosphorIconsFill.identificationCard, label: s.plate, value: 'DHAKA-GA-11-1234'),
                  _VehicleRow(icon: PhosphorIconsFill.palette, label: s.color, value: 'Red'),
                  _VehicleRow(icon: PhosphorIconsFill.wrench, label: s.model, value: 'Honda CB150'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(s.manageAccount, style: AppText.subhead()),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.batterySaver, style: AppText.label()),
                    subtitle: Text(s.driverBatteryHint, style: AppText.helper()),
                    value: saver,
                    activeThumbColor: AppColors.navy900,
                    onChanged: (v) =>
                        context.read<DriverSessionCubit>().setBatterySaver(v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.language, style: AppText.label()),
                    trailing: Text(
                      s.isBn ? s.bangla : s.english,
                      style: AppText.helper(),
                    ),
                    onTap: () => context.read<LocaleCubit>().toggle(),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.logout, style: AppText.label(AppColors.danger)),
                    onTap: () => context.read<SessionCubit>().logout(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _kycLabel(S s, DriverOnboardingStatus? status) {
    return switch (status) {
      DriverOnboardingStatus.approved => s.driverKycApproved,
      DriverOnboardingStatus.grace => s.driverKycGrace,
      DriverOnboardingStatus.pendingReview => s.driverKycPending,
      _ => s.driverKycPending,
    };
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
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
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.navy900, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppText.caption(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.navy700),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppText.helper())),
          Text(value, style: AppText.label()),
        ],
      ),
    );
  }
}

/// Full-screen earnings (deep link / back stack).
class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBarBack(title: s.earnings),
      body: const DriverEarningsTab(),
    );
  }
}

/// Full-screen profile (deep link).
class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBarBack(title: s.profile),
      body: const DriverAccountTab(),
    );
  }
}
