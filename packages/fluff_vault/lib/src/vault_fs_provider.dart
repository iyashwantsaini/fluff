import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fluff_vfs/fluff_vfs.dart';

import 'stream_cipher.dart';
import 'vault.dart';

/// Mounts an unlocked [Vault] as an [FsProvider].
///
/// The vault tree lives in memory (decrypted from the header on
/// unlock). File reads / writes go through XChaCha20-Poly1305
/// streaming AEAD. The per-file blobs and the encrypted header
/// live on a backing [FsProvider] under [containerDir].
class VaultFsProvider implements FsProvider {
  VaultFsProvider({
    required this.backing,
    required this.containerDir,
    required Vault vault,
    this.id = 'vault',
    this.displayName = 'Vault',
  }) : _vault = vault;

  /// The backing provider that holds the encrypted blobs + header.
  final FsProvider backing;

  /// Directory on [backing] where `vault.hdr` + `blobs/<fileId>`
  /// live.
  final FsPath containerDir;

  final Vault _vault;

  Vault get vault => _vault;

  @override
  final String id;

  @override
  final String displayName;

  @override
  final FsCapabilities capabilities = FsCapabilities.full;

  @override
  final FsPath root = FsPath.root;

  FsPath get _headerPath => containerDir.child('vault.hdr');

  FsPath _blobPath(String fileId) => containerDir.child('blobs').child(fileId);

  @override
  Future<FsNode?> stat(FsPath path) async {
    final entry = _vault.tree.entries[path.toString()];
    if (entry == null) return null;
    return FsNode(
      path: path,
      kind: entry.isDirectory ? FsNodeKind.directory : FsNodeKind.file,
      size: entry.size,
      modified: entry.modified,
      mimeType: entry.mimeType,
    );
  }

  @override
  Future<List<FsNode>> list(FsPath dir) async {
    final prefix = dir.isRoot ? '/' : '${dir.toString()}/';
    final out = <FsNode>[];
    for (final e in _vault.tree.entries.entries) {
      if (e.key == dir.toString()) continue;
      if (!e.key.startsWith(prefix)) continue;
      final remainder = e.key.substring(prefix.length);
      if (remainder.isEmpty || remainder.contains('/')) continue;
      out.add(FsNode(
        path: FsPath.parse(e.key),
        kind: e.value.isDirectory ? FsNodeKind.directory : FsNodeKind.file,
        size: e.value.size,
        modified: e.value.modified,
        mimeType: e.value.mimeType,
      ));
    }
    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  @override
  Future<Uint8List> readBytes(FsPath file) async {
    final entry = _vault.tree.entries[file.toString()];
    if (entry == null || entry.isDirectory) {
      throw StateError('not a vault file: $file');
    }
    final fileId = entry.fileId!;
    final blob = await backing.readBytes(_blobPath(fileId));
    return decryptFile(keys: _vault.keys, blob: blob);
  }

  @override
  Future<void> writeBytes(FsPath file, Uint8List bytes) async {
    final parentPath = file.parent.toString();
    if (parentPath != '/' && !_vault.tree.entries.containsKey(parentPath)) {
      throw StateError('parent missing: $parentPath');
    }
    // Generate a per-file salt and encrypt.
    final salt = _randomBytes(kFileSaltLen);
    final blob = await encryptFile(
      keys: _vault.keys,
      plaintext: bytes,
      fileSalt: salt,
    );
    // If file already existed, reuse its fileId so blob count
    // stays stable; else allocate one.
    final existing = _vault.tree.entries[file.toString()];
    String fileId;
    if (existing != null && existing.fileId != null) {
      fileId = existing.fileId!;
    } else {
      fileId = _vault.addFile(
        path: file.toString(),
        size: bytes.length,
      );
    }
    if (existing != null) {
      // refresh size / mtime
      _vault.removeAt(file.toString());
      _vault.addFile(
        path: file.toString(),
        size: bytes.length,
      );
      // re-fetch the just-assigned id and replace blob under the
      // new id; keep things simple for the web slice.
      fileId = _vault.tree.entries[file.toString()]!.fileId!;
    }
    await _ensureBlobsDir();
    await backing.writeBytes(_blobPath(fileId), blob);
    await _persistHeader();
  }

  @override
  Future<void> delete(FsPath path, {bool recursive = false}) async {
    final key = path.toString();
    final entry = _vault.tree.entries[key];
    if (entry == null) return;
    if (entry.isDirectory) {
      final prefix = '$key/';
      final children =
          _vault.tree.entries.keys.where((k) => k.startsWith(prefix)).toList();
      if (children.isNotEmpty && !recursive) {
        throw StateError('directory not empty: $path');
      }
      for (final c in children) {
        final id = _vault.removeAt(c);
        if (id != null) {
          await backing.delete(_blobPath(id));
        }
      }
      _vault.removeAt(key);
    } else {
      final id = _vault.removeAt(key);
      if (id != null) {
        await backing.delete(_blobPath(id));
      }
    }
    await _persistHeader();
  }

  @override
  Future<void> rename(FsPath from, FsPath to) async {
    final entry = _vault.tree.entries[from.toString()];
    if (entry == null) throw StateError('missing: $from');
    _vault.removeAt(from.toString());
    if (entry.isDirectory) {
      _vault.addDirectory(to.toString());
    } else {
      // preserve fileId by re-inserting tree entry manually
      // through addFile + we keep the same blob.
      final newId = _vault.addFile(
        path: to.toString(),
        size: entry.size,
        modified: entry.modified,
        mimeType: entry.mimeType,
      );
      // Move blob from oldId to newId if id changed.
      if (entry.fileId != null && entry.fileId != newId) {
        final blob = await backing.readBytes(_blobPath(entry.fileId!));
        await backing.writeBytes(_blobPath(newId), blob);
        await backing.delete(_blobPath(entry.fileId!));
      }
    }
    await _persistHeader();
  }

  @override
  Future<void> mkdir(FsPath path, {bool recursive = false}) async {
    if (recursive) {
      final parts = path.toString().split('/').where((p) => p.isNotEmpty);
      var cur = '';
      for (final p in parts) {
        cur = '$cur/$p';
        if (!_vault.tree.entries.containsKey(cur)) {
          _vault.addDirectory(cur);
        }
      }
    } else {
      _vault.addDirectory(path.toString());
    }
    await _persistHeader();
  }

  Future<void> _ensureBlobsDir() async {
    final dir = containerDir.child('blobs');
    if (await backing.stat(dir) == null) {
      await backing.mkdir(dir, recursive: true);
    }
  }

  Future<void> _persistHeader() async {
    final bytes = await _vault.reencryptHeader();
    await backing.writeBytes(_headerPath, bytes);
  }

  /// One-shot persist on creation. Caller must invoke after
  /// constructing a fresh vault.
  Future<void> persistInitial() async {
    if (await backing.stat(containerDir) == null) {
      await backing.mkdir(containerDir, recursive: true);
    }
    await _ensureBlobsDir();
    await backing.writeBytes(_headerPath, _vault.header.toBytes());
  }

  /// Load + unlock a vault from a backing directory.
  static Future<VaultFsProvider> unlockFromBacking({
    required FsProvider backing,
    required FsPath containerDir,
    required String password,
  }) async {
    final hdr = await backing.readBytes(containerDir.child('vault.hdr'));
    final vault = await Vault.unlock(headerBytes: hdr, password: password);
    return VaultFsProvider(
      backing: backing,
      containerDir: containerDir,
      vault: vault,
    );
  }
}

Uint8List _randomBytes(int n) {
  final rng = Random.secure();
  final b = Uint8List(n);
  for (var i = 0; i < n; i++) {
    b[i] = rng.nextInt(256);
  }
  return b;
}
