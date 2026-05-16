import 'dart:typed_data';

import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:test/test.dart';

void main() {
  group('FsPath', () {
    test('parses and round-trips', () {
      expect(FsPath.parse('/').toString(), '/');
      expect(FsPath.parse('/a/b/c').toString(), '/a/b/c');
      expect(FsPath.parse('/a//b/').toString(), '/a/b');
    });

    test('normalises . and ..', () {
      expect(FsPath.parse('/a/./b').toString(), '/a/b');
      expect(FsPath.parse('/a/b/../c').toString(), '/a/c');
      expect(FsPath.parse('/../a').toString(), '/a');
    });

    test('parent and child', () {
      final p = FsPath.parse('/a/b');
      expect(p.parent.toString(), '/a');
      expect(p.child('c').toString(), '/a/b/c');
      expect(FsPath.root.parent, FsPath.root);
    });

    test('rejects slashes in child segment', () {
      expect(() => FsPath.parse('/a').child('b/c'), throwsArgumentError);
    });
  });

  group('MemFsProvider.demo', () {
    test('lists root sorted, dirs first', () async {
      final fs = MemFsProvider.demo();
      final entries = await fs.list(FsPath.root);
      expect(entries.first.isDirectory, isTrue);
      final names = entries.map((e) => e.name).toList();
      expect(names, containsAll(['Documents', 'Pictures', 'Downloads']));
    });

    test('stat returns null for missing path', () async {
      final fs = MemFsProvider.demo();
      expect(await fs.stat(FsPath.parse('/nope')), isNull);
    });

    test('read / write / delete round-trip', () async {
      final fs = MemFsProvider();
      final p = FsPath.parse('/hello.txt');
      await fs.writeBytes(p, Uint8List.fromList('hi'.codeUnits));
      final read = await fs.readBytes(p);
      expect(String.fromCharCodes(read), 'hi');
      await fs.delete(p);
      expect(await fs.stat(p), isNull);
    });

    test('mkdir recursive creates parents', () async {
      final fs = MemFsProvider();
      await fs.mkdir(FsPath.parse('/a/b/c'), recursive: true);
      expect((await fs.stat(FsPath.parse('/a/b/c')))?.isDirectory, isTrue);
      expect((await fs.stat(FsPath.parse('/a/b')))?.isDirectory, isTrue);
    });

    test('rename moves subtree', () async {
      final fs = MemFsProvider.demo();
      await fs.rename(FsPath.parse('/Documents'), FsPath.parse('/Docs'));
      expect(await fs.stat(FsPath.parse('/Documents')), isNull);
      final docs = await fs.list(FsPath.parse('/Docs'));
      expect(docs.map((n) => n.name), contains('notes.txt'));
    });
  });
}
