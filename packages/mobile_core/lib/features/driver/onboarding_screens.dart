import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/api_backend.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';

class DriverPersonalScreen extends StatefulWidget {
  const DriverPersonalScreen({super.key});

  @override
  State<DriverPersonalScreen> createState() => _DriverPersonalScreenState();
}

class _DriverPersonalScreenState extends State<DriverPersonalScreen> {
  final name = TextEditingController();
  final nid = TextEditingController();
  final dob = TextEditingController(text: '1995-01-15');
  final address = TextEditingController();
  String? _error;

  @override
  void dispose() {
    name.dispose();
    nid.dispose();
    dob.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final n = name.text.trim();
    final id = nid.text.trim();
    final dobStr = dob.text.trim();
    if (n.length < 2 ||
        !(id.length == 10 || id.length == 17) ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dobStr)) {
      setState(() => _error = S.of(context).nameHelper);
      return;
    }
    setState(() => _error = null);
    final session = context.read<SessionCubit>();
    await session.saveName(n);
    final api = ApiBackend.peek();
    if (api != null) {
      try {
        await api.savePersonal(
          name: n,
          nid: id,
          dateOfBirth: dobStr,
          address: address.text.trim(),
        );
        if (!mounted) return;
        await session.setOnboarding(DriverOnboardingStatus.personalDone);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _error = e.message);
        return;
      }
    }
    if (!mounted) return;
    await session.setOnboarding(DriverOnboardingStatus.personalDone);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBarBack(title: s.personalTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          const _Steps(index: 1),
          const SizedBox(height: 24),
          AppTextField(label: s.nameLabel, controller: name, errorText: _error),
          const SizedBox(height: 16),
          AppTextField(
            label: s.nidLabel,
            controller: nid,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 17,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: s.dobLabel,
            controller: dob,
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 16),
          AppTextField(label: s.addressLabel, controller: address),
          const SizedBox(height: 32),
          AppButton(label: s.continueCta, onPressed: _next),
        ],
      ),
    );
  }
}

class DriverVehicleScreen extends StatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  String type = 'BIKE';
  final make = TextEditingController(text: 'Honda');
  final model = TextEditingController(text: 'Shine');
  final year = TextEditingController(text: '2019');
  final color = TextEditingController(text: 'Black');
  final plate = TextEditingController();

  @override
  void dispose() {
    make.dispose();
    model.dispose();
    year.dispose();
    color.dispose();
    plate.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (plate.text.trim().isEmpty) return;
    final y = int.tryParse(year.text) ?? 0;
    if (y < 2015) return;
    final session = context.read<SessionCubit>();
    final api = ApiBackend.peek();
    if (api != null) {
      try {
        await api.saveVehicle(
          vehicleType: type,
          plate: plate.text.trim(),
          make: make.text.trim(),
          model: model.text.trim(),
          color: color.text.trim(),
          year: y,
        );
        if (!mounted) return;
        await session.setOnboarding(DriverOnboardingStatus.grace);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }
    }
    if (!mounted) return;
    await session.setOnboarding(DriverOnboardingStatus.grace);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBarBack(title: s.vehicleTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          const _Steps(index: 2),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChipApp(
                  label: s.bike,
                  selected: type == 'BIKE',
                  onTap: () => setState(() => type = 'BIKE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChipApp(
                  label: s.car,
                  selected: type == 'CAR',
                  onTap: () => setState(() => type = 'CAR'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(label: s.make, controller: make),
          const SizedBox(height: 16),
          AppTextField(label: s.model, controller: model),
          const SizedBox(height: 16),
          AppTextField(
            label: s.year,
            controller: year,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppTextField(label: s.color, controller: color),
          const SizedBox(height: 16),
          AppTextField(label: s.plate, controller: plate),
          const SizedBox(height: 32),
          AppButton(label: s.continueCta, onPressed: _next),
        ],
      ),
    );
  }
}

class DriverDocumentsScreen extends StatelessWidget {
  const DriverDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final docs = s.isBn
        ? ['NID', 'লাইসেন্স', 'ব্লু বুক', 'ট্যাক্স টোকেন', 'প্রোফাইল ছবি', 'গাড়ির ছবি']
        : ['NID', 'License', 'Blue book', 'Tax token', 'Profile photo', 'Vehicle photo'];
    return Scaffold(
      appBar: AppBarBack(title: s.documentsTitle),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          children: [
            const _Steps(index: 3),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final d in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(child: Text(d, style: AppText.label())),
                            AppBadge(label: s.isBn ? 'খালি' : 'Empty', tone: BadgeTone.warning),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AppButton(
              label: s.submitDocs,
              onPressed: () async {
                final api = ApiBackend.peek();
                final session = context.read<SessionCubit>();
                if (api != null) {
                  try {
                    await api.submitDriverForReview();
                  } on ApiException catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                    return;
                  }
                }
                if (!context.mounted) return;
                await session.setOnboarding(DriverOnboardingStatus.pendingReview);
              },
            ),
            const SizedBox(height: 8),
            AppButton(
              label: s.skip,
              variant: AppButtonVariant.secondary,
              onPressed: () => context
                  .read<SessionCubit>()
                  .setOnboarding(DriverOnboardingStatus.grace),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverPendingScreen extends StatelessWidget {
  const DriverPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              AppBadge(label: s.pendingTitle, tone: BadgeTone.warning),
              const SizedBox(height: 16),
              Text(s.pendingTitle, style: AppText.title()),
              const SizedBox(height: 8),
              Text(s.pendingBody, style: AppText.body()),
              const Spacer(),
              AppButton(
                label: s.logout,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.read<SessionCubit>().logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverRejectedScreen extends StatelessWidget {
  const DriverRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBadge(label: s.rejectedTitle, tone: BadgeTone.danger),
              const SizedBox(height: 16),
              Text(s.rejectedTitle, style: AppText.title()),
              const Spacer(),
              AppButton(
                label: s.reupload,
                onPressed: () => context
                    .read<SessionCubit>()
                    .setOnboarding(DriverOnboardingStatus.docsPending),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final on = i < index;
        return Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 8),
            decoration: BoxDecoration(
              color: on ? AppColors.navy900 : AppColors.borderDefault,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}
