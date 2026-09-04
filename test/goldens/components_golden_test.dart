import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch/app/nav_bar.dart';
import 'package:perch/core/theme/app_theme.dart';
import 'package:perch/core/theme/palette.dart';
import 'package:perch/core/theme/tokens.dart';
import 'package:perch/shared/widgets/app_button.dart';
import 'package:perch/shared/widgets/tag_chip.dart';

/// Goldens for the pieces the boards specify exactly, so a change to spacing,
/// radius or colour has to be deliberate.
///
/// Refresh with: `flutter test --update-goldens test/goldens`.
Widget frame(Widget child, Tone tone) {
  // The nav pill reads the blur setting, which comes from the defaults here —
  // no database is touched until something is written.
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.of(ThemeFamily.perch, tone),
      debugShowCheckedModeBanner: false,
      // A Scaffold, because every one of these components is only ever drawn
      // inside one — InkWell needs the Material.
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.screen),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Goldens are only worth having if they render the real typeface — without
/// this the text draws as boxes and the type scale is not guarded at all.
Future<void> loadFonts() async {
  const Map<String, List<String>> families = <String, List<String>>{
    'Instrument Sans': <String>['assets/fonts/InstrumentSans-Variable.ttf'],
    'Instrument Serif': <String>['assets/fonts/InstrumentSerif-Regular.ttf'],
  };
  for (final MapEntry<String, List<String>> family in families.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then(
          (List<int> bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
        ),
      );
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadFonts);

  for (final Tone tone in <Tone>[Tone.light, Tone.dark]) {
    testWidgets('buttons · ${tone.name}', (WidgetTester tester) async {
      await tester.pumpWidget(
        frame(
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: <Widget>[
              for (final AppButtonType type in AppButtonType.values)
                AppButton(label: type.name, type: type, onPressed: () {}),
              const AppButton(label: 'Disabled', onPressed: null),
              AppButton(label: 'Loading', loading: true, onPressed: () {}),
            ],
          ),
          tone,
        ),
      );
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('buttons_${tone.name}.png'),
      );
    });

    testWidgets('chips · ${tone.name}', (WidgetTester tester) async {
      await tester.pumpWidget(
        frame(
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              const TagChip(label: 'default', dot: true),
              TagChip(label: 'selected', selected: true, onTap: () {}),
              TagChip(label: 'active filter', selected: true, onRemove: () {}),
              TagChip(label: 'add', add: true, onTap: () {}),
            ],
          ),
          tone,
        ),
      );
      await expectLater(
        find.byType(Wrap).first,
        matchesGoldenFile('chips_${tone.name}.png'),
      );
    });

    testWidgets('nav pill · ${tone.name}', (WidgetTester tester) async {
      await tester.pumpWidget(
        frame(
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.row,
            children: <Widget>[
              PerchNavPill(index: 0, onSelect: (int _) {}),
              PerchFab(onTap: () {}),
            ],
          ),
          tone,
        ),
      );
      await expectLater(
        find.byType(Row).first,
        matchesGoldenFile('nav_pill_${tone.name}.png'),
      );
    });
  }
}
