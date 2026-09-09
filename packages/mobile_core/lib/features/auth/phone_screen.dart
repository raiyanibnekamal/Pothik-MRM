import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/connectivity/connectivity_cubit.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  late final TextEditingController _c = TextEditingController(text: BdPhone.qaLocal);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final online = context.read<ConnectivityCubit>().state;
    if (!online) {
      showAppSnack(context, s.otpOffline, error: true);
      return;
    }
    final v = BdPhone.normalize(_c.text);
    if (!BdPhone.isValid(v)) {
      setState(() => _error = s.badPhone);
      return;
    }
    setState(() => _error = null);
    try {
      await context.read<SessionCubit>().requestOtp(v, online: online);
      if (mounted) context.push('/otp');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == ErrorCodes.rateLimit) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.rateLimit, style: AppText.subhead()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.done, style: AppText.label(AppColors.navy900)),
              ),
            ],
          ),
        );
      } else {
        setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = context.watch<SessionCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(s.brand, style: AppText.title())),
                  TextButton(
                    onPressed: () => context.read<LocaleCubit>().toggle(),
                    child: Text(
                      s.isBn ? s.english : s.bangla,
                      style: AppText.label(AppColors.navy900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(s.phoneLabel, style: AppText.subhead()),
              const SizedBox(height: 24),
              AppTextField(
                label: s.phoneLabel,
                controller: _c,
                hint: s.phoneHint,
                helper: s.phoneHelper,
                errorText: _error,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => _error = null),
              ),
              const Spacer(),
              AppButton(
                label: s.getOtp,
                loading: session.busy,
                onPressed: session.busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
