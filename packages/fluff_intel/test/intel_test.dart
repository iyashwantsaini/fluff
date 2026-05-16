import 'package:fluff_intel/fluff_intel.dart';
import 'package:test/test.dart';

void main() {
  group('SemanticIndex', () {
    final idx = SemanticIndex(seed: defaultSeedIndex());

    test('ranks exact token hits highest', () {
      final r = idx.search('invoice internet');
      expect(r, isNotEmpty);
      expect(r.first.path, '/Downloads/invoice-2026-03.pdf');
      expect(r.first.score, closeTo(1.0, 0.001));
    });

    test('returns empty for unknown tokens', () {
      expect(idx.search('asdfghjkl'), isEmpty);
    });

    test('limits results', () {
      expect(idx.search('photo', limit: 1).length, 1);
    });
  });

  group('OrganisePlanner', () {
    test('produces a non-empty plan for /Downloads', () {
      final plan = const OrganisePlanner().proposeForDownloads();
      expect(plan.actions, isNotEmpty);
      expect(plan.title, contains('Downloads'));
      expect(plan.moveCount, greaterThan(0));
    });
  });

  group('OcrResult', () {
    test('joins block text', () {
      const r = OcrResult(
        sourcePath: '/x.png',
        language: 'en',
        blocks: [
          OcrBlock(text: 'Hello', left: 0, top: 0, width: 0.5, height: 0.1),
          OcrBlock(text: 'World', left: 0, top: 0.2, width: 0.5, height: 0.1),
        ],
      );
      expect(r.fullText, 'Hello\nWorld');
    });
  });
}
