import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

import 'header.dart';

/// In-memory holder for derived vault keys. Lifetimes are caller's
/// responsibility — call [dispose] (or just drop the reference) on
/// lock.
@immutable
class VaultKeys {
  const VaultKeys({required this.masterKey}) : assert(masterKey.length == 32);

  /// Raw 256-bit master key. Stays in memory while the vault is
  /// unlocked. **Never** persisted in plaintext.
  final Uint8List masterKey;

  /// Derive a per-file key via HKDF-SHA256 (PLAN §6.5).
  Future<Uint8List> deriveFileKey(Uint8List fileSalt) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: fileSalt,
      info: _fileInfo,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  static final _fileInfo = Uint8List.fromList('fluff-file-v1'.codeUnits);
}

/// Derive a key-encryption key from a password via Argon2id and
/// the parameters baked into the vault header.
Future<SecretKey> deriveKekFromPassword({
  required String password,
  required Argon2Params params,
}) async {
  final argon = Argon2id(
    memory: params.memKib,
    parallelism: params.lanes,
    iterations: params.ops,
    hashLength: 32,
  );
  return argon.deriveKeyFromPassword(password: password, nonce: params.salt);
}

/// Wrap the master key with the password-derived KEK using
/// XChaCha20-Poly1305 (24-byte nonce, 16-byte tag, no AAD).
Future<Uint8List> wrapMasterKey({
  required SecretKey kek,
  required Uint8List nonce,
  required Uint8List masterKey,
}) async {
  final aead = Xchacha20.poly1305Aead();
  final box = await aead.encrypt(masterKey, secretKey: kek, nonce: nonce);
  // wrapped = ciphertext || mac.bytes (mac always 16 bytes)
  return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
}

/// Reverse of [wrapMasterKey]. Throws [SecretBoxAuthenticationError]
/// on wrong password or tamper.
Future<Uint8List> unwrapMasterKey({
  required SecretKey kek,
  required Uint8List nonce,
  required Uint8List wrapped,
}) async {
  if (wrapped.length < 16) {
    throw const FormatException('wrapped master key too short');
  }
  final mac = Mac(wrapped.sublist(wrapped.length - 16));
  final ct = wrapped.sublist(0, wrapped.length - 16);
  final aead = Xchacha20.poly1305Aead();
  final plain = await aead.decrypt(
    SecretBox(ct, nonce: nonce, mac: mac),
    secretKey: kek,
  );
  return Uint8List.fromList(plain);
}
