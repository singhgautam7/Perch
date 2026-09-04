import 'package:flutter_test/flutter_test.dart';
import 'package:perch/features/link_detail/note_view.dart';

void main() {
  group('NoteView.toggleAt', () {
    const String note = 'Quote for the talk.\n'
        '- [x] pull the durability line\n'
        '- [ ] check the 2019 footnote\n'
        'trailing prose';

    test('ticks an unticked item', () {
      expect(
        NoteView.toggleAt(note, 2),
        contains('- [x] check the 2019 footnote'),
      );
    });

    test('unticks a ticked one', () {
      expect(
        NoteView.toggleAt(note, 1),
        contains('- [ ] pull the durability line'),
      );
    });

    test('leaves prose and every other line alone', () {
      final List<String> before = note.split('\n');
      final List<String> after = NoteView.toggleAt(note, 2).split('\n');
      expect(after.length, before.length);
      expect(after[0], before[0]);
      expect(after[1], before[1]);
      expect(after[3], before[3]);
    });

    test('a line that is not a checkbox is a no-op', () {
      expect(NoteView.toggleAt(note, 0), note);
      expect(NoteView.toggleAt(note, 99), note);
    });

    test('keeps the original bullet marker and indent', () {
      expect(NoteView.toggleAt('  * [ ] nested', 0), '  * [x] nested');
    });
  });
}
