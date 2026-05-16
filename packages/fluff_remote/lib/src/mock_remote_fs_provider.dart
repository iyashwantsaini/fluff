import 'dart:async';
import 'dart:typed_data';

import 'package:fluff_vfs/fluff_vfs.dart';

import 'remote_account.dart';

/// In-memory [FsProvider] that simulates a remote share for the Phase
/// 4 web slice. Backed by a [MemFsProvider] seeded with a tree whose
/// shape depends on the account [RemoteKind] so SMB and SFTP look
/// distinct in the UI.
class MockRemoteFsProvider implements FsProvider {
  MockRemoteFsProvider({required this.account})
    : _backing = _seed(account),
      id = 'remote:${account.id}',
      displayName = account.label;

  /// Source account.
  final RemoteAccount account;

  final MemFsProvider _backing;

  @override
  final String id;

  @override
  final String displayName;

  @override
  FsCapabilities get capabilities => _backing.capabilities;

  @override
  FsPath get root => _backing.root;

  @override
  Future<FsNode?> stat(FsPath path) => _backing.stat(path);

  @override
  Future<List<FsNode>> list(FsPath dir) => _backing.list(dir);

  @override
  Future<Uint8List> readBytes(FsPath file) => _backing.readBytes(file);

  @override
  Future<void> writeBytes(FsPath file, Uint8List bytes) =>
      _backing.writeBytes(file, bytes);

  @override
  Future<void> delete(FsPath path, {bool recursive = false}) =>
      _backing.delete(path, recursive: recursive);

  @override
  Future<void> rename(FsPath from, FsPath to) => _backing.rename(from, to);

  @override
  Future<void> mkdir(FsPath path, {bool recursive = false}) =>
      _backing.mkdir(path, recursive: recursive);

  static MemFsProvider _seed(RemoteAccount account) {
    final mem = MemFsProvider(
      id: 'remote-backing:${account.id}',
      displayName: account.label,
    );
    // Seed a kind-specific tree synchronously via writeBytes/mkdir.
    if (account.kind == RemoteKind.smb) {
      _seedSmb(mem);
    } else {
      _seedSftp(mem);
    }
    return mem;
  }

  static void _seedSmb(MemFsProvider mem) {
    // unawaited — MemFsProvider operations are synchronous internally.
    mem.mkdir(FsPath.parse('/Shared'));
    mem.mkdir(FsPath.parse('/Shared/Photos'));
    mem.mkdir(FsPath.parse('/Shared/Movies'));
    mem.mkdir(FsPath.parse('/Public'));
    mem.writeBytes(FsPath.parse('/Shared/Photos/family.jpg'), Uint8List(0));
    mem.writeBytes(FsPath.parse('/Shared/Movies/holiday.mp4'), Uint8List(0));
    mem.writeBytes(
      FsPath.parse('/Public/announcement.txt'),
      Uint8List.fromList('Welcome to the share!\n'.codeUnits),
    );
  }

  static void _seedSftp(MemFsProvider mem) {
    mem.mkdir(FsPath.parse('/home'));
    mem.mkdir(FsPath.parse('/home/deploy'));
    mem.mkdir(FsPath.parse('/var'));
    mem.mkdir(FsPath.parse('/var/log'));
    mem.writeBytes(
      FsPath.parse('/home/deploy/.bashrc'),
      Uint8List.fromList('# managed by fluff\nexport PATH=\$PATH\n'.codeUnits),
    );
    mem.writeBytes(
      FsPath.parse('/var/log/sshd.log'),
      Uint8List.fromList('sshd: accepted publickey\n'.codeUnits),
    );
  }
}
