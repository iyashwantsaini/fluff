import 'package:meta/meta.dart';

/// A single semantic-index entry — a file plus a short snippet and
/// a list of tokens the index searches against.
@immutable
class IndexEntry {
  const IndexEntry({
    required this.path,
    required this.snippet,
    required this.tokens,
    this.score = 0,
  });

  final String path;
  final String snippet;
  final List<String> tokens;
  final double score;

  IndexEntry withScore(double s) => IndexEntry(
        path: path,
        snippet: snippet,
        tokens: tokens,
        score: s,
      );
}

/// Toy in-memory semantic index. Real implementation in Phase 8.1
/// would use sqlite-vec + on-device embeddings.
class SemanticIndex {
  SemanticIndex({Iterable<IndexEntry> seed = const []}) {
    _entries.addAll(seed);
  }

  final List<IndexEntry> _entries = [];

  List<IndexEntry> get entries => List.unmodifiable(_entries);

  void add(IndexEntry e) => _entries.add(e);

  /// Tokenises [query] on whitespace, lowercases, and ranks entries
  /// by the fraction of query tokens that appear in each entry's
  /// token list. Stable, deterministic — good enough for a mock.
  List<IndexEntry> search(String query, {int limit = 10}) {
    final qs = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (qs.isEmpty) return const [];
    final scored = <IndexEntry>[];
    for (final e in _entries) {
      final lower = e.tokens.map((t) => t.toLowerCase()).toSet();
      var hit = 0;
      for (final q in qs) {
        if (lower.contains(q)) hit++;
      }
      if (hit > 0) {
        scored.add(e.withScore(hit / qs.length));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }
}

/// Seed used by the app's web slice so the Search screen has
/// something to query against.
List<IndexEntry> defaultSeedIndex() => const [
      IndexEntry(
        path: '/Documents/notes.txt',
        snippet: 'Project meeting notes — Q2 roadmap, sync engine, '
            'nearby transfers.',
        tokens: ['project', 'meeting', 'notes', 'sync', 'roadmap', 'q2'],
      ),
      IndexEntry(
        path: '/Documents/lease.pdf',
        snippet: 'Residential lease agreement, signed 2025-08-14.',
        tokens: ['lease', 'residential', 'agreement', 'rent', 'contract'],
      ),
      IndexEntry(
        path: '/Pictures/2026-04/sunset.jpg',
        snippet: 'Orange sunset over the hills — exposure 1/250s.',
        tokens: ['sunset', 'photo', 'orange', 'hills', 'evening'],
      ),
      IndexEntry(
        path: '/Pictures/2026-04/family.jpg',
        snippet: 'Family group photo, four people, outdoor.',
        tokens: ['family', 'photo', 'people', 'group', 'outdoor'],
      ),
      IndexEntry(
        path: '/Downloads/invoice-2026-03.pdf',
        snippet: 'Invoice 2026-03 — internet service, due 2026-04-15.',
        tokens: ['invoice', 'bill', 'internet', 'march', 'due'],
      ),
      IndexEntry(
        path: '/Downloads/recipe-pasta.md',
        snippet: 'Pasta recipe — garlic, olive oil, parmesan.',
        tokens: ['recipe', 'pasta', 'garlic', 'food', 'cooking'],
      ),
    ];
