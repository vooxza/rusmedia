import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 password hashing. The encoded format is:
/// pbkdf2_sha256$iterations$salt_base64url$derived_key_base64url
class PasswordHasher {
  static const int iterations = 210000;
  static const int saltLength = 16;
  static const int keyLength = 32;

  static String hash(String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(saltLength, (_) => random.nextInt(256)),
    );
    final derivedKey = _pbkdf2(
      utf8.encode(password),
      salt,
      iterations,
      keyLength,
    );

    return 'pbkdf2_sha256\$$iterations\$'
        '${base64Url.encode(salt).replaceAll('=', '')}\$'
        '${base64Url.encode(derivedKey).replaceAll('=', '')}';
  }

  static bool verify(String password, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') return false;

    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 10000 || rounds > 1000000) return false;

    try {
      final salt = base64Url.decode(base64Url.normalize(parts[2]));
      final expected = base64Url.decode(base64Url.normalize(parts[3]));
      final actual =
          _pbkdf2(utf8.encode(password), salt, rounds, expected.length);
      if (actual.length != expected.length) return false;

      var difference = 0;
      for (var i = 0; i < actual.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  static Uint8List _pbkdf2(
    List<int> password,
    Uint8List salt,
    int rounds,
    int length,
  ) {
    final hmac = Hmac(sha256, password);
    final blockCount = (length + 31) ~/ 32;
    final output = BytesBuilder(copy: false);

    for (var block = 1; block <= blockCount; block++) {
      final blockInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;

      var u = Uint8List.fromList(hmac.convert(blockInput).bytes);
      final accumulator = Uint8List.fromList(u);

      for (var round = 1; round < rounds; round++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var i = 0; i < accumulator.length; i++) {
          accumulator[i] ^= u[i];
        }
      }
      output.add(accumulator);
    }

    return Uint8List.fromList(output.takeBytes().sublist(0, length));
  }
}
