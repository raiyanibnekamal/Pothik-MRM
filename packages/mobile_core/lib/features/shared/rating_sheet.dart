import 'package:flutter/material.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

Future<void> showRatingSheet(
  BuildContext context, {
  required Future<void> Function() onSubmit,
}) {
  return showAppSheet<void>(
    context: context,
    isDismissible: false,
    child: _RatingBody(onSubmit: onSubmit),
  );
}

class _RatingBody extends StatefulWidget {
  const _RatingBody({required this.onSubmit});
  final Future<void> Function() onSubmit;

  @override
  State<_RatingBody> createState() => _RatingBodyState();
}

class _RatingBodyState extends State<_RatingBody> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.rateTitle, style: AppText.title()),
          const SizedBox(height: 16),
          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              return IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => setState(() => _stars = n),
                icon: Icon(
                  n <= _stars
                      ? PhosphorIconsFill.star
                      : PhosphorIconsRegular.star,
                  color: n <= _stars
                      ? AppColors.interactiveAccent
                      : AppColors.textDisabled,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: s.submit,
            onPressed: _stars == 0
                ? null
                : () async {
                    await widget.onSubmit();
                  },
          ),
        ],
      ),
    );
  }
}
