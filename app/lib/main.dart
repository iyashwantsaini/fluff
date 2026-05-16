import 'package:fluff_ops/fluff_ops.dart';
import 'package:fluff_skin/fluff_skin.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:flutter/material.dart';

import 'src/browse_screen.dart';

void main() {
  runApp(const FluffApp());
}

class FluffApp extends StatefulWidget {
  const FluffApp({super.key});

  @override
  State<FluffApp> createState() => _FluffAppState();
}

class _FluffAppState extends State<FluffApp> {
  final SkinController _skin = SkinController(
    mode: Uri.base.queryParameters['dark'] == '1'
        ? ThemeMode.dark
        : ThemeMode.system,
  );
  late final FsProvider _fs = MemFsProvider.demo();
  late final OperationQueue _queue = OperationQueue(
    providerLookup: (id) => id == _fs.id ? _fs : null,
  );

  @override
  void dispose() {
    _skin.dispose();
    _queue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkinScope(
      controller: _skin,
      builder: (context, light, dark, mode) => MaterialApp(
        title: 'Fluff',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        home: BrowseScreen(
          provider: _fs,
          queue: _queue,
          onToggleBrightness: () => _skin.toggleBrightness(context),
        ),
      ),
    );
  }
}
