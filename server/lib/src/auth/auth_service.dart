import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import 'password_hasher.dart';

class AuthService {
  AuthService(this.pool);

  final Pool<void> pool;
  static const Duration sessionLifetime = Duration(days: 30);

  Future<Map<String, Object?>?> login({
    required String email,
    required String password,
    String? userAgent,
  }) async {
    final result = await pool.execute(
      Sql.named('''
        SELECT id::text, email, name, password_hash, role::text, is_active
        FROM users
        WHERE lower(email) = @email
        LIMIT 1
      '''),
      parameters: {'email': email.trim().toLowerCase()},
    );

    if (result.isEmpty) return null;
    final row = result.first;
    final passwordHash = row[3] as String;
    final isActive = row[5] as bool;

    if (!isActive || !PasswordHasher.verify(password, passwordHash)) {
      return null;
    }

    final token = _newToken();
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final expiresAt = DateTime.now().toUtc().add(sessionLifetime);

    await pool.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO sessions (token_hash, user_id, expires_at, user_agent)
          VALUES (@token_hash, @user_id, @expires_at, @user_agent)
        '''),
        parameters: {
          'token_hash': tokenHash,
          'user_id': row[0] as String,
          'expires_at': expiresAt,
          'user_agent': userAgent,
        },
      );
      await tx.execute(
        Sql.named(
            'UPDATE users SET last_login_at = now(), updated_at = now() WHERE id = @id::uuid'),
        parameters: {'id': row[0] as String},
      );
    });

    return {
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
      'user': _publicUser(row),
    };
  }

  Future<Map<String, Object?>?> userForToken(String token) async {
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final result = await pool.execute(
      Sql.named('''
        SELECT u.id::text, u.email, u.name, u.role::text
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = @token_hash
          AND s.expires_at > now()
          AND u.is_active = true
        LIMIT 1
      '''),
      parameters: {'token_hash': tokenHash},
    );

    if (result.isEmpty) return null;
    return {
      'id': result.first[0] as String,
      'email': result.first[1] as String,
      'name': result.first[2] as String,
      'role': result.first[3] as String,
    };
  }

  Future<void> logout(String token) async {
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    await pool.execute(
      Sql.named('DELETE FROM sessions WHERE token_hash = @token_hash'),
      parameters: {'token_hash': tokenHash},
    );
  }

  static Map<String, Object?> _publicUser(dynamic row) => {
        'id': row[0] as String,
        'email': row[1] as String,
        'name': row[2] as String,
        'role': row[4] as String,
      };

  static String _newToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
