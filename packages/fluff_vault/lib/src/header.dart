import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Magic prefix for the vault header.
const List<int> kVaultMagic = [
  0x46, 0x4C, 0x55, 0x46, 0x46, 0x76, 0x31, 0x00, // "FLUFFv1\0"
];

/// AEAD algorithm identifiers (PLAN §6.4).
enum AeadId {
  xchacha20Poly1305(1),
  aes256Gcm(2);

  const AeadId(this.value);
  final int value;

  static AeadId fromValue(int v) => AeadId.values.firstWhere(
    (a) => a.value == v,
    orElse: () => throw FormatException('unknown aead_id $v'),
  );
}

/// Argon2id parameters baked into the header.
@immutable
class Argon2Params {
  const Argon2Params({
    required this.memKib,
    required this.ops,
    required this.lanes,
    required this.salt,
  }) : assert(salt.length == 32, 'salt must be 32 bytes');

  final int memKib;
  final int ops;
  final int lanes;
  final Uint8List salt;

  /// Light parameters suitable for tests and the web demo. **Not**
  /// for real on-device vaults — production picks per-device per
  /// PLAN §6.3.
  factory Argon2Params.lightWith(Uint8List salt) =>
      Argon2Params(memKib: 8 * 1024, ops: 2, lanes: 1, salt: salt);
}

/// In-memory representation of `vault.hdr` (PLAN §6.4).
@immutable
class VaultHeader {
  const VaultHeader({
    required this.version,
    required this.kdf,
    required this.aead,
    required this.headerNonce,
    required this.wrappedMasterKey,
    required this.treeNonce,
    required this.encryptedTree,
  }) : assert(headerNonce.length == 24),
       assert(treeNonce.length == 24);

  final int version;
  final Argon2Params kdf;
  final AeadId aead;
  final Uint8List headerNonce;
  final Uint8List wrappedMasterKey;
  final Uint8List treeNonce;
  final Uint8List encryptedTree;

  Uint8List toBytes() {
    final out = BytesBuilder();
    out.add(kVaultMagic);
    out.add(_u16(version));
    out.addByte(1); // kdf_id = argon2id
    out.add(_u32(kdf.memKib));
    out.add(_u32(kdf.ops));
    out.addByte(kdf.lanes);
    out.add(kdf.salt);
    out.addByte(aead.value);
    out.add(headerNonce);
    out.add(_u32(wrappedMasterKey.length));
    out.add(wrappedMasterKey);
    out.add(treeNonce);
    out.add(_u32(encryptedTree.length));
    out.add(encryptedTree);
    return out.toBytes();
  }

  static VaultHeader parse(Uint8List bytes) {
    final r = _Reader(bytes);
    final magic = r.take(8);
    for (var i = 0; i < kVaultMagic.length; i++) {
      if (magic[i] != kVaultMagic[i]) {
        throw const FormatException('not a fluff vault');
      }
    }
    final version = r.u16();
    final kdfId = r.u8();
    if (kdfId != 1) {
      throw FormatException('unsupported kdf_id $kdfId');
    }
    final memKib = r.u32();
    final ops = r.u32();
    final lanes = r.u8();
    final salt = r.take(32);
    final aead = AeadId.fromValue(r.u8());
    final headerNonce = r.take(24);
    final wrappedLen = r.u32();
    final wrappedMasterKey = r.take(wrappedLen);
    final treeNonce = r.take(24);
    final treeLen = r.u32();
    final encryptedTree = r.take(treeLen);
    return VaultHeader(
      version: version,
      kdf: Argon2Params(
        memKib: memKib,
        ops: ops,
        lanes: lanes,
        salt: Uint8List.fromList(salt),
      ),
      aead: aead,
      headerNonce: Uint8List.fromList(headerNonce),
      wrappedMasterKey: Uint8List.fromList(wrappedMasterKey),
      treeNonce: Uint8List.fromList(treeNonce),
      encryptedTree: Uint8List.fromList(encryptedTree),
    );
  }
}

/// In-memory directory tree stored inside the header.
///
/// Encoded as JSON for the v0.1 web slice; CBOR per PLAN §6.4 is
/// the v1 wire format (same shape, smaller).
@immutable
class VaultTree {
  const VaultTree({required this.entries});

  /// Path → entry (path always starts with `/`).
  final Map<String, VaultTreeEntry> entries;

  Uint8List toBytes() {
    final m = <String, dynamic>{
      for (final e in entries.entries)
        e.key: {
          'kind': e.value.kind,
          'size': e.value.size,
          'mtime': e.value.modified?.toIso8601String(),
          'mime': e.value.mimeType,
          'fileId': e.value.fileId,
        },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(m)));
  }

  static VaultTree parse(Uint8List bytes) {
    final m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return VaultTree(
      entries: {
        for (final e in m.entries)
          e.key: VaultTreeEntry(
            kind: (e.value as Map)['kind'] as String,
            size: (e.value as Map)['size'] as int,
            modified: (e.value as Map)['mtime'] == null
                ? null
                : DateTime.parse((e.value as Map)['mtime'] as String),
            mimeType: (e.value as Map)['mime'] as String?,
            fileId: (e.value as Map)['fileId'] as String?,
          ),
      },
    );
  }

  VaultTree withEntry(String path, VaultTreeEntry e) =>
      VaultTree(entries: {...entries, path: e});

  VaultTree without(String path) {
    final m = {...entries}..remove(path);
    return VaultTree(entries: m);
  }
}

/// Single tree entry.
@immutable
class VaultTreeEntry {
  const VaultTreeEntry({
    required this.kind, // 'file' | 'directory'
    required this.size,
    this.modified,
    this.mimeType,
    this.fileId,
  });

  final String kind;
  final int size;
  final DateTime? modified;
  final String? mimeType;

  /// Random 256-bit id (hex) for the on-disk blob. `null` for dirs.
  final String? fileId;

  bool get isDirectory => kind == 'directory';
}

// ---------- little-endian readers / writers ----------

Uint8List _u16(int v) {
  final b = ByteData(2)..setUint16(0, v, Endian.little);
  return b.buffer.asUint8List();
}

Uint8List _u32(int v) {
  final b = ByteData(4)..setUint32(0, v, Endian.little);
  return b.buffer.asUint8List();
}

class _Reader {
  _Reader(this.bytes);
  final Uint8List bytes;
  int o = 0;

  List<int> take(int n) {
    final s = bytes.sublist(o, o + n);
    o += n;
    return s;
  }

  int u8() => bytes[o++];
  int u16() {
    final v = ByteData.sublistView(bytes, o, o + 2).getUint16(0, Endian.little);
    o += 2;
    return v;
  }

  int u32() {
    final v = ByteData.sublistView(bytes, o, o + 4).getUint32(0, Endian.little);
    o += 4;
    return v;
  }
}
