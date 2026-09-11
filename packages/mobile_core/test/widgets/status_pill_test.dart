import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/features/passenger/status_pill.dart';

// Minimal wrapper. StatusPill calls S.of(context); the fallback inside S.of
// (S(const Locale('bn'))) returns Bengali strings when no localization
// delegate is registered, which matches the production default.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('requested renders bn label "ড্রাইভার খোঁজা হচ্ছে"', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill(status: RideStatus.requested)));
    expect(find.text('ড্রাইভার খোঁজা হচ্ছে'), findsOneWidget);
  });

  testWidgets('English locale has canonical "Finding a driver"', (tester) async {
    // Pin the English source-of-truth string used by tracking_screen.dart.
    expect(S(const Locale('en')).findingDriver, 'Finding a driver');
  });

  testWidgets('driverArrived shows "ড্রাইভার পৌঁছেছে" with success tone', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill(status: RideStatus.driverArrived)));
    expect(find.text('ড্রাইভার পৌঁছেছে'), findsOneWidget);

    // StatusPill wraps its pill in an AnimatedContainer whose decoration is
    // the tone-aware border + shadow. Pull that AnimatedContainer and check
    // the border color matches the success tone.
    final animated = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = animated.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.border!.top.color, AppColors.success);
  });

  testWidgets('etaMin renders "আসছে N মিনিটে"', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusPill(status: RideStatus.driverArriving, etaMin: 7)),
    );
    expect(find.text('আসছে 7 মিনিটে'), findsOneWidget);
  });

  testWidgets('falls back to "ড্রাইভার আসছে" when etaMin is null', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill(status: RideStatus.driverArriving)));
    expect(find.text('ড্রাইভার আসছে'), findsOneWidget);
  });

  testWidgets('completed renders "ট্রিপ সম্পন্ন" with a static dot', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill(status: RideStatus.completed)));
    expect(find.text('ট্রিপ সম্পন্ন'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(PulsingDot), matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(PulsingDot), matching: find.byType(Container)),
      findsOneWidget,
    );
  });

  testWidgets('label updates when status flips accepted -> inProgress', (tester) async {
    await tester.pumpWidget(_wrap(const StatusPill(status: RideStatus.accepted)));
    expect(find.text('ড্রাইভার আসছে'), findsOneWidget);

    await tester.pumpWidget(_wrap(const StatusPill(status: RideStatus.inProgress)));
    await tester.pump();
    expect(find.text('ট্রিপ শুরু হয়েছে'), findsOneWidget);
  });
}
