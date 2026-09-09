import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/session/session_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_spacing.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/app_fields.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  Timer? _t;
  int _left = 60;
  int _shake = 0;
  bool _error = false;
  String _code = '';

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    try {
      await context.read<SessionCubit>().verifyOtp(code);
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _error = true;
        _shake++;
        _code = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = context.watch<SessionCubit>().state;
    final phone = session.otpPhone ?? '';
    return Scaffold(
      appBar: AppBarBack(title: s.otpTitle),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.otpSentTo(BdPhone.display(phone)), style: AppText.body()),
            if (BdPhone.isQa(phone)) ...[
              const SizedBox(height: 8),
              Text(s.otpHelper, style: AppText.helper()),
            ],
            const SizedBox(height: 24),
            CodeBoxes(
              length: 6,
              error: _error,
              shakeToken: _shake,
              initialValue: BdPhone.isQa(phone) ? BdPhone.qaOtp : null,
              onChanged: (v) {
                setState(() => _code = v);
              },
              onCompleted: _verify,
            ),
            if (session.error != null) ...[
              const SizedBox(height: 12),
              Text(session.error!, style: AppText.helper(AppColors.danger)),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: s.verifyOtp,
              loading: session.busy,
              onPressed: _code.length == 6 && !session.busy
                  ? () => _verify(_code)
                  : null,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: _left > 0 ? s.resendIn(_left) : s.resendOtp,
              variant: AppButtonVariant.text,
              onPressed: _left == 0
                  ? () async {
                      await context.read<SessionCubit>().requestOtp(
                            phone,
                            online: true,
                          );
                      setState(() => _left = 60);
                      _tick();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
