import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/mock_backend.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';

Future<void> showGuardianPrompt(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).guardianTitle, style: AppText.title()),
          const SizedBox(height: 8),
          Text(S.of(context).guardianBody, style: AppText.body(AppColors.textSecondary)),
          const SizedBox(height: 24),
          AppButton(
            label: S.of(context).addGuardian,
            onPressed: () {
              Navigator.pop(context);
              showGuardianForm(context);
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: S.of(context).skip,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

Future<void> showGuardianForm(BuildContext context) {
  final name = TextEditingController();
  final phone = TextEditingController();
  return showAppSheet<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(label: S.of(context).nameLabel, controller: name),
          const SizedBox(height: 16),
          AppTextField(
            label: S.of(context).phoneLabel,
            controller: phone,
            keyboardType: TextInputType.phone,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('+880', style: AppText.fare()),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: S.of(context).save,
            onPressed: () async {
              try {
                await context.read<MockBackend>().addGuardian(
                      name.text.trim(),
                      '+880${phone.text.trim()}',
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  showAppSnack(context, e.toString(), error: true);
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}

class GuardiansScreen extends StatelessWidget {
  const GuardiansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final list = context.read<MockBackend>().guardians;
    return Scaffold(
      appBar: AppBarBack(title: s.guardians),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          children: [
            if (list.isEmpty)
              Expanded(
                child: EmptyState(
                  title: s.guardians,
                  body: s.guardianBody,
                  cta: s.addGuardian,
                  onCta: () => showGuardianForm(context),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final g in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(g.name, style: AppText.label()),
                        subtitle: Text(g.phone, style: AppText.helper()),
                      ),
                  ],
                ),
              ),
            if (list.length < 3)
              AppButton(
                label: s.addGuardian,
                onPressed: () => showGuardianForm(context),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<SessionCubit>().state.user;
    return Scaffold(
      appBar: AppBarBack(title: s.profile),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? '', style: AppText.title()),
                const SizedBox(height: 8),
                Text(user?.phone ?? '', style: AppText.fare()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(s.guardians, style: AppText.label()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GuardiansScreen()),
            ),
          ),
          ListTile(
            title: Text(s.settings, style: AppText.label()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          ListTile(
            title: Text(s.legal, style: AppText.label()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalScreen()),
            ),
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBarBack(title: s.settings),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.language, style: AppText.subhead()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChipApp(
                    label: s.bangla,
                    selected: s.isBn,
                    onTap: () => context.read<LocaleCubit>().setCode('bn'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChipApp(
                    label: s.english,
                    selected: !s.isBn,
                    onTap: () => context.read<LocaleCubit>().setCode('en'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBarBack(title: s.legal),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          _doc(s.terms, _terms),
          _doc(s.privacy, _privacy),
          _doc(s.community, _community),
        ],
      ),
    );
  }

  Widget _doc(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.subhead()),
            const SizedBox(height: 8),
            Text(body, style: AppText.body()),
          ],
        ),
      ),
    );
  }
}

const _terms =
    'BD Ride Share provides ride matching in Bangladesh. Cash fares are locked by the server. You must follow community rules and local law.';
const _privacy =
    'Phone number is the account. Location is used for pickup, dispatch, SOS, and trip share. We do not sell your data. SOS packets go to guardians and ops.';
const _community =
    'No harassment. Match the plate. PIN before you sit. Cancel with a reason. Drivers keep the cabin safe.';
