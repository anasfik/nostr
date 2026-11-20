import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_playground/main.dart';

void main() {
  for (final initial in Brightness.values) {
    testWidgets('theme toggle inverts system ${initial.name} on first click', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = initial;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(const NostrPlaygroundApp());
      await tester.pumpAndSettle();
      Brightness current() =>
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
      expect(current(), initial);
      await tester.tap(find.byTooltip('Toggle light or dark theme'));
      await tester.pumpAndSettle();
      expect(
        current(),
        initial == Brightness.light ? Brightness.dark : Brightness.light,
      );
      await tester.tap(find.byTooltip('Toggle light or dark theme'));
      await tester.pumpAndSettle();
      expect(current(), initial);
    });
  }
}
