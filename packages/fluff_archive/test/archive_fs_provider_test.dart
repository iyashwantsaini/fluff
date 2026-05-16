import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fluff_archive/fluff_archive.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:test/test.dart';

Uint8List _buildZip() {
  final archive = Archive()
    ..addFile(ArchiveFile.string('readme.txt', 'hello archive'))
    ..addFile(ArchiveFile.string('docs/intro.md', '# Intro\n'))
    ..addFile(ArchiveFile.string('docs/api/v1.json', '{"v":1}'))
    ..addFile(ArchiveFile.string('logo.png', '\x89PNG\r\n'));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('ArchiveFormat.sniff', () {
    test('zip / tar / tar.gz', () {
      expect(ArchiveFormat.sniff('foo.zip'), ArchiveFormat.zip);
      expect(ArchiveFormat.sniff('FOO.TAR'), ArchiveFormat.tar);
      expect(ArchiveFormat.sniff('blob.tar.gz'), ArchiveFormat.tarGz);
      expect(ArchiveFormat.sniff('blob.tgz'), ArchiveFormat.tarGz);
      expect(ArchiveFormat.sniff('readme.md'), isNull);
    });
  });

  group('ArchiveFsProvider (zip)', () {
    late ArchiveFsProvider p;

    setUp(() {
      p = ArchiveFsProvider.fromBytes(
        bytes: _buildZip(),
        format: ArchiveFormat.zip,
        displayName: 'sample.zip',
      );
    });

    test('capabilities are read-only', () {
      expect(p.capabilities.canRead, isTrue);
      expect(p.capabilities.canWrite, isFalse);
    });

    test('root lists synthesised directories + files', () async {
      final root = await p.list(FsPath.root);
      final names = root.map((n) => n.name).toList()..sort();
      expect(names, ['docs', 'logo.png', 'readme.txt']);
      expect(root.firstWhere((n) => n.name == 'docs').isDirectory, isTrue);
    });

    test('nested directory listing', () async {
      final docs = await p.list(FsPath.parse('/docs'));
      final names = docs.map((n) => n.name).toList()..sort();
      expect(names, ['api', 'intro.md']);
    });

    test('readBytes returns original content', () async {
      final bytes = await p.readBytes(FsPath.parse('/readme.txt'));
      expect(String.fromCharCodes(bytes), 'hello archive');
    });

    test('write / delete / rename / mkdir all throw', () {
      expect(
        () => p.writeBytes(FsPath.parse('/x'), Uint8List(0)),
        throwsUnsupportedError,
      );
      expect(
        () => p.delete(FsPath.parse('/readme.txt')),
        throwsUnsupportedError,
      );
      expect(
        () => p.rename(FsPath.parse('/a'), FsPath.parse('/b')),
        throwsUnsupportedError,
      );
      expect(() => p.mkdir(FsPath.parse('/new')), throwsUnsupportedError);
    });

    test('stat for missing path returns null', () async {
      expect(await p.stat(FsPath.parse('/does-not-exist')), isNull);
    });
  });
}
