import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/core/widgets/app_widgets.dart';

void main() {
  testWidgets('AppButton label shrinks instead of overflowing a narrow button',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            // The width from the reported crash.
            child: SizedBox(
              width: 264,
              child: AppButton(
                label: 'A very long call to action label',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('A very long call to action label'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
  });

  testWidgets('AppButton without an icon fits a narrow button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: AppButton(
                label: 'Next Question Please Continue',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Next Question Please Continue'), findsOneWidget);
  });
}
