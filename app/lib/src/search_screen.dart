import 'package:fluff_intel/fluff_intel.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:flutter/material.dart';

/// Phase 8 web slice: queries a [SemanticIndex] and renders the
/// ranked snippets.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.index,
    required this.drawer,
    this.onToggleBrightness,
    this.initialQuery,
  });

  final SemanticIndex index;
  final Drawer drawer;
  final VoidCallback? onToggleBrightness;
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  late List<IndexEntry> _results = widget.initialQuery == null
      ? const []
      : widget.index.search(widget.initialQuery!);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run() {
    setState(() {
      _results = widget.index.search(_ctrl.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WlmTheme.of(context).tokens;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          if (widget.onToggleBrightness != null)
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6_outlined),
              onPressed: widget.onToggleBrightness,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.lg,
              vertical: tokens.spacing.md,
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Try "invoice", "photo", "recipe"…',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _run,
                ),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? _Empty(query: _ctrl.text)
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.lg,
                    ),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: tokens.spacing.sm),
                    itemBuilder: (context, i) => _ResultTile(entry: _results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.travel_explore_rounded,
            size: 56,
            color: cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery
                ? 'No matches for "$query".'
                : 'Search across your files — OCR text, captions, tags.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.entry});
  final IndexEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = WlmTheme.of(context).tokens;
    final pct = (entry.score * 100).round();
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: const Icon(Icons.description_outlined),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.path,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$pct%',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.snippet,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
