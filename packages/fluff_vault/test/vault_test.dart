import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:fluff_vault/fluff_vault.dart';
import 'package:fluff_vfs/fluff_vfs.dart';
import 'package:test/test.dart';

void main() {
  group('header round-trip', () {
    test('encodes and decodes losslessly', () {
      final salt = Uint8List.fromList(List.generate(32, (i) => i));
      final headerNonce = Uint8List.fromList(List.generate(24, (i) => 100 + i));
      final treeNonce = Uint8List.fromList(List.generate(24, (i) => 200 + i));
      final wrapped = Uint8List.fromList(List.generate(48, (i) => i * 2));
      final encTree = Uint8List.fromList(List.generate(64, (i) => 255 - i));

      final h = VaultHeader(
        version: 1,
        kdf: Argon2Params.lightWith(salt),
        aead: AeadId.xchacha20Poly1305,
        headerNonce: headerNonce,
        wrappedMasterKey: wrapped,
        treeNonce: treeNonce,
        encryptedTree: encTree,
      );

      final bytes = h.toBytes();
      final parsed = VaultHeader.parse(bytes);

      expect(parsed.version, h.version);
      expect(parsed.kdf.memKib, h.kdf.memKib);
      expect(parsed.kdf.ops, h.kdf.ops);
      expect(parsed.kdf.lanes, h.kdf.lanes);
      expect(parsed.kdf.salt, h.kdf.salt);
      expect(parsed.aead, h.aead);
      expect(parsed.headerNonce, h.headerNonce);
      expect(parsed.wrappedMasterKey, h.wrappedMasterKey);
      expect(parsed.treeNonce, h.treeNonce);
      expect(parsed.encryptedTree, h.encryptedTree);
    });

    test('rejects wrong magic', () {
      final bytes = Uint8List.fromList(List.filled(128, 0));
      expect(() => VaultHeader.parse(bytes), throwsFormatException);
    });
  });

  group('streaming AEAD', () {
    test('encrypt → decrypt round-trips small payload', () async {
      final v = await Vault.create(password: 'correct horse');
      final plaintext = Uint8List.fromList(
        'the quick brown fox jumps over the lazy dog'.codeUnits,
      );
      final salt = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final blob = await encryptFile(
        keys: v.keys,
        plaintext: plaintext,
        fileSalt: salt,
      );
      // Magic + salt + ciphertext + tag
      expect(blob.length, kFileMagic.length + 32 + plaintext.length + 16);
      final dec = await decryptFile(keys: v.keys, blob: blob);
      expect(dec, plaintext);
    });

    test('encrypt → decrypt round-trips multi-chunk payload', () async {
      final v = await Vault.create(password: 'correct horse');
      // 200 KiB ⇒ 4 chunks (64 + 64 + 64 + 8).
      final plaintext = Uint8List(200 * 1024);
      for (var i = 0; i < plaintext.length; i++) {
        plaintext[i] = i & 0xff;
      }
      final salt = Uint8List.fromList(List.generate(32, (i) => i + 7));
      final blob = await encryptFile(
        keys: v.keys,
        plaintext: plaintext,
        fileSalt: salt,
      );
      final dec = await decryptFile(keys: v.keys, blob: blob);
      expect(dec.length, plaintext.length);
      expect(dec, plaintext);
    });

    test('tampered ciphertext fails authentication', () async {
      final v = await Vault.create(password: 'correct horse');
      final plaintext = Uint8List.fromList(List.filled(100, 42));
      final salt = Uint8List.fromList(List.generate(32, (i) => i));
      final blob = await encryptFile(
        keys: v.keys,
        plaintext: plaintext,
        fileSalt: salt,
      );
      // flip one ciphertext byte (right after magic+salt)
      blob[kFileMagic.length + 32] ^= 0x01;
      expect(
        () => decryptFile(keys: v.keys, blob: blob),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('vault lifecycle', () {
    test('create → reencrypt header → unlock round-trips', () async {
      final v = await Vault.create(password: 'hunter2');
      final hdrBytes = await v.reencryptHeader();
      final v2 = await Vault.unlock(
        headerBytes: hdrBytes,
        password: 'hunter2',
      );
      expect(v2.tree.entries.containsKey('/'), isTrue);
      expect(v2.keys.masterKey, v.keys.masterKey);
    });

    test('wrong password is rejected', () async {
      final v = await Vault.create(password: 'right');
      final hdrBytes = await v.reencryptHeader();
      expect(
        () => Vault.unlock(headerBytes: hdrBytes, password: 'wrong'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('VaultFsProvider', () {
    test('write → list → read round-trips through encrypted blobs', () async {
      final backing = MemFsProvider(id: 'mem-backing');
      final v = await Vault.create(password: 'open sesame');
      final provider = VaultFsProvider(
        backing: backing,
        containerDir: FsPath.parse('/container'),
        vault: v,
      );
      await provider.persistInitial();
      await provider.writeBytes(
        FsPath.parse('/hello.txt'),
        Uint8List.fromList('hello vault'.codeUnits),
      );
      final list = await provider.list(FsPath.root);
      expect(list.length, 1);
      expect(list.first.name, 'hello.txt');
      expect(list.first.size, 'hello vault'.length);
      final read = await provider.readBytes(FsPath.parse('/hello.txt'));
      expect(String.fromCharCodes(read), 'hello vault');

      // and the blob on the backing FS is *not* plaintext
      final blobs = await backing.list(FsPath.parse('/container/blobs'));
      expect(blobs.length, 1);
      final blob = await backing.readBytes(blobs.first.path);
      expect(blob.length, greaterThan('hello vault'.length));
      expect(
        String.fromCharCodes(blob),
        isNot(contains('hello vault')),
      );
    });

    test('delete removes both tree entry and blob', () async {
      final backing = MemFsProvider();
      final v = await Vault.create(password: 'pw');
      final p = VaultFsProvider(
        backing: backing,
        containerDir: FsPath.parse('/c'),
        vault: v,
      );
      await p.persistInitial();
      await p.writeBytes(FsPath.parse('/a.txt'), Uint8List.fromList([1, 2, 3]));
      var blobs = await backing.list(FsPath.parse('/c/blobs'));
      expect(blobs.length, 1);
      await p.delete(FsPath.parse('/a.txt'));
      blobs = await backing.list(FsPath.parse('/c/blobs'));
      expect(blobs, isEmpty);
      expect(await p.stat(FsPath.parse('/a.txt')), isNull);
    });
  });
}
