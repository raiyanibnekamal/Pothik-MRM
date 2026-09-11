import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/features/passenger/status_pill.dart';

Widget _wrapNoL10n(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('no-l10n StatusPill uses S fallback (bn)', (tester) async {
    await tester.pumpWidget(_wrapNoL10n(
      const StatusPill(status: RideStatus.requested),
    ));
    final textWidgets = find.byType(Text);
    print('Text count = ${textWidgets.evaluate().length}');
    for (final el in textWidgets.evaluate()) {
      final w = el.widget as Text;
      print('  data = "${w.data}"');
    }
    expect(find.text('ড্রাইভার খোঁজা হচ্ছে'), findsOneWidget);
  });
}




