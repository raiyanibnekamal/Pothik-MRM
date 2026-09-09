import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    final v = _c.text.trim();
    if (v.length < 2 || v.length > 100) {
      setState(() => _error = s.nameHelper);
      return;
    }
    await context.read<SessionCubit>().saveName(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final busy = context.watch<SessionCubit>().state.busy;
    return Scaffold(
      appBar: AppBarBack(
        title: s.profileSetupTitle,
        onBack: null,
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => context.read<SessionCubit>().logout(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'out', child: Text(s.logout)),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          children: [
            AppTextField(
              label: s.nameLabel,
              controller: _c,
              helper: s.nameHelper,
              errorText: _error,
            ),
            const SizedBox(height: 24),
            Text(s.photoOptional, style: AppText.helper()),
            const Spacer(),
            AppButton(
              label: s.continueCta,
              loading: busy,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
