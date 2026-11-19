import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_playground/src/playground_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('brand palette matches the shared light and dark tokens', () {
    expect(playgroundLightColors.background, const Color(0xFFF6F8FC));
    expect(playgroundLightColors.surface, const Color(0xFFFFFFFF));
    expect(playgroundLightColors.ink, const Color(0xFF17263E));
    expect(playgroundLightColors.muted, const Color(0xFF4A5B73));
    expect(playgroundLightColors.border, const Color(0xFFCBD5E2));
    expect(playgroundLightColors.accent, const Color(0xFF245AC4));
    expect(playgroundLightColors.success, const Color(0xFF1B7F3B));

    expect(playgroundDarkColors.background, const Color(0xFF111B2B));
    expect(playgroundDarkColors.surface, const Color(0xFF18263B));
    expect(playgroundDarkColors.ink, const Color(0xFFECF1FA));
    expect(playgroundDarkColors.muted, const Color(0xFFB6C4DA));
    expect(playgroundDarkColors.border, const Color(0xFF43536C));
    expect(playgroundDarkColors.accent, const Color(0xFF95BBFF));
    expect(playgroundDarkColors.success, const Color(0xFF6FCF97));
  });

  test('light tokens keep text, accent and success readable', () {
    final c = playgroundLightColors;
    expect(_contrast(c.ink, c.background), greaterThanOrEqualTo(7));
    expect(_contrast(c.ink, c.surface), greaterThanOrEqualTo(7));
    expect(_contrast(c.muted, c.background), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.accent, c.background), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.accent, c.surface), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.success, c.surface), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.success, c.background), greaterThanOrEqualTo(4.5));
  });

  test('dark tokens keep text, accent and success readable', () {
    final c = playgroundDarkColors;
    expect(_contrast(c.ink, c.background), greaterThanOrEqualTo(7));
    expect(_contrast(c.ink, c.surface), greaterThanOrEqualTo(7));
    expect(_contrast(c.muted, c.background), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.accent, c.background), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.accent, c.surface), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.success, c.surface), greaterThanOrEqualTo(4.5));
  });

  for (final brightness in Brightness.values) {
    test(
      'theme uses brand primary and IBM Plex Sans in ${brightness.name}',
      () {
        final theme = buildPlaygroundTheme(brightness);
        final colors = brightness == Brightness.dark
            ? playgroundDarkColors
            : playgroundLightColors;

        expect(theme.brightness, brightness);
        expect(theme.colorScheme.primary, colors.accent);
        expect(theme.colorScheme.surface, colors.surface);
        expect(theme.colorScheme.onSurface, colors.ink);
        expect(theme.scaffoldBackgroundColor, colors.background);
        expect(theme.textTheme.bodyMedium?.fontFamily, 'IBM Plex Sans');
        expect(
          _contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
        );

        final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(cardShape.borderRadius, BorderRadius.circular(4));
        final inputBorder =
            theme.inputDecorationTheme.border! as OutlineInputBorder;
        expect(inputBorder.borderRadius, BorderRadius.circular(4));
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48),
        );
      },
    );

    test('body text is 16px on a 1.6 line height in ${brightness.name}', () {
      final theme = buildPlaygroundTheme(brightness);
      for (final style in [
        theme.textTheme.bodyLarge!,
        theme.textTheme.bodyMedium!,
      ]) {
        expect(style.fontSize, 16);
        expect(style.height, 1.6);
        expect(style.fontFamily, 'IBM Plex Sans');
        expect(style.color, theme.colorScheme.onSurface);
      }
      expect(theme.textTheme.bodySmall!.fontSize, lessThan(16));
    });

    test(
      'focused button sides are 3px and high contrast in ${brightness.name}',
      () {
        final theme = buildPlaygroundTheme(brightness);
        const focused = <WidgetState>{WidgetState.focused};
        const unfocused = <WidgetState>{};
        final scheme = theme.colorScheme;

        final filled = theme.filledButtonTheme.style!.side!.resolve(focused)!;
        expect(filled.width, 3);
        expect(filled.color, isNot(scheme.primary));
        expect(
          _contrast(filled.color, scheme.primary),
          greaterThanOrEqualTo(3),
        );

        final tonal = playgroundFocusSideStyle(scheme.onSecondaryContainer)
            .side!
            .resolve(focused)!;
        expect(tonal.width, 3);
        expect(
          _contrast(tonal.color, scheme.secondaryContainer),
          greaterThanOrEqualTo(3),
        );

        final sideStyles = <WidgetStateProperty<BorderSide?>?>[
          theme.outlinedButtonTheme.style!.side,
          theme.textButtonTheme.style!.side,
          theme.iconButtonTheme.style!.side,
        ];
        for (final side in sideStyles) {
          final focusedSide = side!.resolve(focused)!;
          expect(focusedSide.width, 3);
          expect(
            _contrast(focusedSide.color, scheme.surface),
            greaterThanOrEqualTo(3),
          );
          expect(side.resolve(unfocused), isNull);
        }
        expect(theme.filledButtonTheme.style!.side!.resolve(unfocused), isNull);
      },
    );
  }

  testWidgets('outlined buttons keep their default side until focused', (
    tester,
  ) async {
    final theme = buildPlaygroundTheme(Brightness.light);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: OutlinedButton(
              key: const Key('outlined-probe'),
              focusNode: focusNode,
              onPressed: () {},
              child: const Text('Probe'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    OutlinedBorder shape() =>
        tester
                .widget<Material>(
                  find
                      .descendant(
                        of: find.byKey(const Key('outlined-probe')),
                        matching: find.byType(Material),
                      )
                      .first,
                )
                .shape!
            as OutlinedBorder;

    expect(shape().side.width, 1);
    expect(shape().side.color, theme.colorScheme.outline);

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(shape().side.width, 3);
    expect(shape().side.color, theme.colorScheme.primary);
  });

  testWidgets('bundles the IBM Plex Sans OFL licence', (tester) async {
    final licence = await rootBundle.loadString('assets/fonts/OFL.txt');
    expect(licence, contains('SIL Open Font License'));
  });
}
