import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/theme/app_theme.dart';
import 'package:perch/core/theme/palette.dart';
import 'package:perch/shared/widgets/app_button.dart';
import 'package:perch/shared/widgets/app_icon_button.dart';
import 'package:perch/shared/widgets/breadcrumb.dart';
import 'package:perch/shared/widgets/tag_chip.dart';

Widget host(Widget child, {Tone tone = Tone.light}) => MaterialApp(
  theme: AppTheme.of(ThemeFamily.perch, tone),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('AppButton fires when enabled and not when disabled', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      host(AppButton(label: 'Save', onPressed: () => taps++)),
    );
    await tester.tap(find.text('Save'));
    expect(taps, 1);

    await tester.pumpWidget(host(const AppButton(label: 'Save', onPressed: null)));
    await tester.tap(find.text('Save'));
    expect(taps, 1);
  });

  testWidgets('AppButton in loading state shows a spinner and blocks taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      host(AppButton(label: 'Save', loading: true, onPressed: () => taps++)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(taps, 0);
  });

  testWidgets('AppIconButton keeps a 48dp target however small it looks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppIconButton(
          icon: Icons.search_rounded,
          onPressed: () {},
          semanticLabel: 'Search',
          size: 36,
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
  });

  testWidgets('TagChip removal is separate from selection', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    int removes = 0;
    await tester.pumpWidget(
      host(
        TagChip(
          label: 'reading',
          selected: true,
          onTap: () => taps++,
          onRemove: () => removes++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(removes, 1);
    expect(taps, 0);
  });

  testWidgets('Breadcrumb collapses the middle when nesting is deep', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Breadcrumb(
          crumbs: <Crumb>[
            Crumb('Root', null),
            Crumb('A', 1),
            Crumb('B', 2),
            Crumb('C', 3),
            Crumb('D', 4),
          ],
        ),
      ),
    );
    expect(find.text('…'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('Breadcrumb shows every crumb when it fits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Breadcrumb(
          crumbs: <Crumb>[Crumb('Root', null), Crumb('Reading', 1)],
        ),
      ),
    );
    expect(find.text('…'), findsNothing);
    expect(find.text('Reading'), findsOneWidget);
  });

  test('every theme family builds in all three tones, and is cached', () {
    for (final ThemeFamily f in ThemeFamily.all) {
      for (final Tone t in Tone.values) {
        expect(AppTheme.of(f, t), same(AppTheme.of(f, t)));
      }
    }
  });
}
