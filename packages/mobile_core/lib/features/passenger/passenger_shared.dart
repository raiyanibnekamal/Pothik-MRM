import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/pressable.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class LocationShareBanner extends StatelessWidget {
  const LocationShareBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Pressable(
      onTap: () => context.push('/permission'),
      borderRadius: BorderRadius.zero,
      child: Container(
        width: double.infinity,
        color: AppColors.warningBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(PhosphorIconsFill.mapPin, size: 18, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.locationBanner, style: AppText.label(AppColors.warning)),
            ),
            const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

Future<void> showScheduleSheet(BuildContext context) {
  final s = S.of(context);
  var later = false;
  return showAppSheet<void>(
    context: context,
    child: StatefulBuilder(
      builder: (context, setLocal) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.whenTrip, style: AppText.title()),
              const SizedBox(height: 20),
              _ScheduleOption(
                icon: PhosphorIconsRegular.clock,
                title: s.tripNow,
                body: s.tripNowBody,
                selected: !later,
                onTap: () => setLocal(() => later = false),
              ),
              const SizedBox(height: 12),
              _ScheduleOption(
                icon: PhosphorIconsRegular.calendarBlank,
                title: s.tripLater,
                body: s.tripLaterBody,
                selected: later,
                onTap: () => setLocal(() => later = true),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: s.done,
                onPressed: () {
                  Navigator.pop(context);
                  if (later) {
                    showAppSnack(context, s.tripLaterBody);
                  }
                  context.push('/passenger/search');
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ScheduleOption extends StatelessWidget {
  const _ScheduleOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, color: AppColors.navy900),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.label()),
                  Text(body, style: AppText.helper()),
                ],
              ),
            ),
            Icon(
              selected
                  ? PhosphorIconsFill.radioButton
                  : PhosphorIconsRegular.circle,
              color: AppColors.navy900,
            ),
          ],
        ),
      ),
    );
  }
}
