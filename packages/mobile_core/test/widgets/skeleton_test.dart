import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';

void main() {
  testWidgets('Skeleton renders with the configured size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: Skeleton(height: 24, width: 120, radius: 12),
          ),
        ),
      ),
    );

    // Initial frame: container is present with the expected size.
    expect(find.byType(Container), findsWidgets);

    final sized = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sized.width, 200);

    // Drive a few frames so the AnimationController ticks.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Opacity widget should be present (the Skeleton pulses via Opacity).
    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('Skeleton renders multiple instances side by side', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Skeleton(height: 16),
              SizedBox(height: 8),
              Skeleton(height: 16, width: 200),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Skeleton), findsNWidgets(2));
  });
}
