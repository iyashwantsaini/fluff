import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'keys.dart';

/// 64 KiB plaintext chunks (PLAN §6.5).
const int kChunkSize = 64 * 1024;

/// 16-byte tag length for Poly1305.
const int kTagLen = 16;

/// 24-byte nonce length for XChaCha20.
const int kNonceLen = 24;

/// 32-byte per-file salt baked at the start of every blob.
const int kFileSaltLen = 32;

/// Per-file magic at the start of every blob: `FLUFFFILEv1\0\0\0\0\0`
/// (16 bytes).
final Uint8List kFileMagic = Uint8List.fromList([
  0x46, 0x4C, 0x55, 0x46, 0x46, 0x46, 0x49, 0x4C, // FLUFFFIL
  0x45, 0x76, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, // Ev1.....
]);

/// Encrypt [plaintext] into the per-file blob layout described in
/// PLAN §6.5 (magic + per-file salt + N chunks of ciphertext+tag).
///
/// Derives a fresh per-file key from [keys] and a random
/// [fileSalt] (caller supplies 32 random bytes — exposed so tests
/// can pin them).
Future<Uint8List> encryptFile({
  required VaultKeys keys,
  required Uint8List plaintext,
  required Uint8List fileSalt,
}) async {
  if (fileSalt.length != kFileSaltLen) {
    throw ArgumentError('fileSalt must be $kFileSaltLen bytes');
  }
  final fileKey = await keys.deriveFileKey(fileSalt);
  final aead = Xchacha20.poly1305Aead();
  final out = BytesBuilder();
  out.add(kFileMagic);
  out.add(fileSalt);

  final totalChunks = plaintext.isEmpty
      ? 1
      : ((plaintext.length + kChunkSize - 1) ~/ kChunkSize);

  for (var i = 0; i < totalChunks; i++) {
    final start = i * kChunkSize;
    final end = (start + kChunkSize > plaintext.length)
        ? plaintext.length
        : start + kChunkSize;
    final chunk = plaintext.sublist(start, end);
    final box = await aead.encrypt(
      chunk,
      secretKey: SecretKey(fileKey),
      nonce: _chunkNonce(i),
    );
    out.add(box.cipherText);
    out.add(box.mac.bytes);
  }
  return out.toBytes();
}

/// Decrypt a blob produced by [encryptFile]. Throws on tamper or
/// wrong key.
Future<Uint8List> decryptFile({
  required VaultKeys keys,
  required Uint8List blob,
}) async {
  if (blob.length < kFileMagic.length + kFileSaltLen) {
    throw const FormatException('blob too short');
  }
  for (var i = 0; i < kFileMagic.length; i++) {
    if (blob[i] != kFileMagic[i]) {
      throw const FormatException('not a fluff vault blob');
    }
  }
  final fileSalt = Uint8List.sublistView(
    blob,
    kFileMagic.length,
    kFileMagic.length + kFileSaltLen,
  );
  final fileKey = await keys.deriveFileKey(Uint8List.fromList(fileSalt));
  final aead = Xchacha20.poly1305Aead();
  var o = kFileMagic.length + kFileSaltLen;
  final out = BytesBuilder();
  var i = 0;
  while (o < blob.length) {
    final remaining = blob.length - o;
    final ctLen =
        (remaining - kTagLen) > kChunkSize ? kChunkSize : (remaining - kTagLen);
    if (ctLen < 0) {
      throw const FormatException('truncated chunk');
    }
    final ct = blob.sublist(o, o + ctLen);
    final mac = Mac(blob.sublist(o + ctLen, o + ctLen + kTagLen));
    o += ctLen + kTagLen;
    final plain = await aead.decrypt(
      SecretBox(ct, nonce: _chunkNonce(i), mac: mac),
      secretKey: SecretKey(fileKey),
    );
    out.add(plain);
    i++;
  }
  return out.toBytes();
}

/// Per-chunk nonce: 24-byte little-endian counter (PLAN §6.5).
Uint8List _chunkNonce(int index) {
  final n = Uint8List(kNonceLen);
  var v = index;
  for (var i = 0; i < 8 && v != 0; i++) {
    n[i] = v & 0xff;
    v >>= 8;
  }
  return n;
}
