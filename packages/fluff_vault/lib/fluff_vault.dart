/// Pure-Dart encrypted vault for Fluff.
///
/// Header format frozen in PLAN.md §6.4. Per-file chunked streaming
/// AEAD (64 KiB chunks) per §6.5.
library;

export 'src/header.dart';
export 'src/keys.dart';
export 'src/stream_cipher.dart';
export 'src/vault.dart';
export 'src/vault_fs_provider.dart';
