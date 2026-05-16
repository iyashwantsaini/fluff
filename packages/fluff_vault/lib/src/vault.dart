import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'header.dart';
import 'keys.dart';

/// Top-level vault object. Lives in memory only when unlocked.
///
/// **Persistence model (web slice)**: header bytes + a map of
/// `fileId → encryptedBlob` are stored on a backing [FsProvider]
/// alongside an opaque container directory. This class itself is
/// transport-agnostic — wiring lives in `VaultFsProvider`.
class Vault {
  Vault._({
    required this.header,
    required this.keys,
    required VaultTree tree,
  }) : _tree = tree;

  final VaultHeader header;
  final VaultKeys keys;
  VaultTree _tree;

  VaultTree get tree => _tree;

  /// Create a brand-new vault from a password. Returns the header
  /// bytes (caller persists them) and an empty in-memory tree.
  static Future<Vault> create({
    required String password,
    Argon2Params? params,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final salt = _rand(rng, 32);
    final kdf = params ?? Argon2Params.lightWith(salt);
    final masterKey = _rand(rng, 32);
    final headerNonce = _rand(rng, 24);
    final treeNonce = _rand(rng, 24);

    final kek = await deriveKekFromPassword(password: password, params: kdf);
    final wrapped = await wrapMasterKey(
      kek: kek,
      nonce: headerNonce,
      masterKey: masterKey,
    );

    final emptyTree = const VaultTree(
        entries: {'/': VaultTreeEntry(kind: 'directory', size: 0)});
    final treeBlob = emptyTree.toBytes();
    final aead = Xchacha20.poly1305Aead();
    final treeBox = await aead.encrypt(
      treeBlob,
      secretKey: SecretKey(masterKey),
      nonce: treeNonce,
    );
    final encTree = Uint8List.fromList([
      ...treeBox.cipherText,
      ...treeBox.mac.bytes,
    ]);

    final header = VaultHeader(
      version: 1,
      kdf: kdf,
      aead: AeadId.xchacha20Poly1305,
      headerNonce: headerNonce,
      wrappedMasterKey: wrapped,
      treeNonce: treeNonce,
      encryptedTree: encTree,
    );
    return Vault._(
      header: header,
      keys: VaultKeys(masterKey: masterKey),
      tree: emptyTree,
    );
  }

  /// Unlock an existing vault from its header bytes + password.
  /// Throws [SecretBoxAuthenticationError] on wrong password.
  static Future<Vault> unlock({
    required Uint8List headerBytes,
    required String password,
  }) async {
    final header = VaultHeader.parse(headerBytes);
    final kek = await deriveKekFromPassword(
      password: password,
      params: header.kdf,
    );
    final masterKey = await unwrapMasterKey(
      kek: kek,
      nonce: header.headerNonce,
      wrapped: header.wrappedMasterKey,
    );
    final aead = Xchacha20.poly1305Aead();
    final mac =
        Mac(header.encryptedTree.sublist(header.encryptedTree.length - 16));
    final ct =
        header.encryptedTree.sublist(0, header.encryptedTree.length - 16);
    final treeBytes = await aead.decrypt(
      SecretBox(ct, nonce: header.treeNonce, mac: mac),
      secretKey: SecretKey(masterKey),
    );
    final tree = VaultTree.parse(Uint8List.fromList(treeBytes));
    return Vault._(
      header: header,
      keys: VaultKeys(masterKey: masterKey),
      tree: tree,
    );
  }

  /// Re-encrypt and return the updated header bytes. Call after
  /// any tree mutation so the persisted header stays in sync.
  Future<Uint8List> reencryptHeader({Random? random}) async {
    final rng = random ?? Random.secure();
    final treeNonce = _rand(rng, 24);
    final aead = Xchacha20.poly1305Aead();
    final box = await aead.encrypt(
      _tree.toBytes(),
      secretKey: SecretKey(keys.masterKey),
      nonce: treeNonce,
    );
    final encTree = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    final updated = VaultHeader(
      version: header.version,
      kdf: header.kdf,
      aead: header.aead,
      headerNonce: header.headerNonce,
      wrappedMasterKey: header.wrappedMasterKey,
      treeNonce: treeNonce,
      encryptedTree: encTree,
    );
    return updated.toBytes();
  }

  /// Add a regular file entry to the tree (caller is responsible
  /// for actually writing the encrypted blob). Returns the random
  /// `fileId` for the new blob.
  String addFile({
    required String path,
    required int size,
    DateTime? modified,
    String? mimeType,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final id = _hex(_rand(rng, 32));
    _tree = _tree.withEntry(
      path,
      VaultTreeEntry(
        kind: 'file',
        size: size,
        modified: modified ?? DateTime.now(),
        mimeType: mimeType,
        fileId: id,
      ),
    );
    return id;
  }

  void addDirectory(String path) {
    _tree = _tree.withEntry(
      path,
      const VaultTreeEntry(kind: 'directory', size: 0),
    );
  }

  /// Remove an entry. Caller deletes the corresponding blob.
  String? removeAt(String path) {
    final e = _tree.entries[path];
    _tree = _tree.without(path);
    return e?.fileId;
  }
}

Uint8List _rand(Random rng, int n) {
  final b = Uint8List(n);
  for (var i = 0; i < n; i++) {
    b[i] = rng.nextInt(256);
  }
  return b;
}

String _hex(Uint8List b) {
  const hex = '0123456789abcdef';
  final out = StringBuffer();
  for (final x in b) {
    out.write(hex[(x >> 4) & 0xf]);
    out.write(hex[x & 0xf]);
  }
  return out.toString();
}
