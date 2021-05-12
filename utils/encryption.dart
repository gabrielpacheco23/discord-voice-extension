import 'dart:ffi';
import 'dart:typed_data';
import 'package:sodium/sodium.dart';
// import 'package:sodium/sodium.ffi.dart' as sodiumffi;
// import 'package:sodium/src/ffi/api/secure_key_ffi.dart';

abstract class Encryption {
  late final Sodium sodium;
  factory Encryption.xSalsa20Poly1305() => _SodiumSecretBox();

  Future<Encryption> init();
  Uint8List randomNonce();

  Uint8List encrypt({
    required Uint8List message,
    required Uint8List nonce,
    required Uint8List key,
  });

  Uint8List decrypt({
    required Uint8List encrypted,
    required Uint8List nonce,
    required Uint8List key,
  });
}

// this encryption works fine with Discord
class _SodiumSecretBox implements Encryption {
  late final Sodium sodium;
  _SodiumSecretBox();

  final libsodium = DynamicLibrary.open('/usr/local/lib/libsodium.so');

  @override
  Future<_SodiumSecretBox> init() async {
    final sodium = await SodiumInit.init(libsodium);

    final self = _SodiumSecretBox();
    self.sodium = sodium;
    return self;
  }

  Uint8List randomNonce() =>
      sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);

  @override
  Uint8List encrypt({
    required Uint8List message,
    required Uint8List nonce,
    required Uint8List key,
  }) {
    return sodium.crypto.secretBox.easy(
      message: message,
      nonce: nonce,
      key: sodium.secureCopy(key),
    );
  }

  @override
  Uint8List decrypt({
    required Uint8List encrypted,
    required Uint8List nonce,
    required Uint8List key,
  }) {
    return sodium.crypto.secretBox.openEasy(
      cipherText: encrypted,
      nonce: nonce,
      key: sodium.secureCopy(key),
    );
  }
}

// extension KeyExt on SecretBox {
//   SecureKey keyFromBytes(Uint8List rawBytes, DynamicLibrary dylib) {
//     final sodiumPtr = sodiumffi.SodiumPointer<Uint8>.alloc(
//       sodiumffi.LibSodiumFFI(dylib),
//       count: rawBytes.length,
//     );

//     sodiumPtr.fill(rawBytes);
//     return SecureKeyFFI(sodiumPtr);
//   }
// }
