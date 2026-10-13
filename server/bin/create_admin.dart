import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:rusmedia_server/src/auth/password_hasher.dart';
import 'package:rusmedia_server/src/db.dart';

Map<String, String> _loadEnv() {
  final env = <String, String>{...Platform.environment};
  final file = File('.env');

  if (file.existsSync()) {
    for (final raw in file.readAsLinesSync()) {
      final line = raw.trim();

      if (line.isEmpty || line.startsWith('#')) continue;

      final index = line.indexOf('=');
      if (index <= 0) continue;

      env.putIfAbsent(
        line.substring(0, index).trim(),
        () => line.substring(index + 1).trim(),
      );
    }
  }

  return env;
}

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run bin/create_admin.dart <email> <name>');
    exit(64);
  }

  final email = args[0].trim().toLowerCase();
  final name = args[1].trim();

  final env = _loadEnv();
  final databaseUrl = env['DATABASE_URL'];

  if (databaseUrl == null || databaseUrl.trim().isEmpty) {
    stderr.writeln('DATABASE_URL tidak ditemukan.');
    exit(64);
  }

  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
      name.isEmpty) {
    stderr.writeln('Email atau nama tidak valid.');
    exit(64);
  }

  final password = _readPassword();

  if (password.length < 12) {
    stderr.writeln('Password harus memiliki minimal 12 karakter.');
    exit(64);
  }

  final pool = createPool(databaseUrl, maxConnections: 1);

  try {
    final existing = await pool.execute(
      Sql.named(
        'SELECT id FROM users WHERE lower(email) = @email LIMIT 1',
      ),
      parameters: {'email': email},
    );

    if (existing.isNotEmpty) {
      await pool.execute(
        Sql.named('''
          UPDATE users
          SET name = @name,
              password_hash = @password_hash,
              role = 'SUPER_ADMIN',
              is_active = true
          WHERE id = @id
        '''),
        parameters: {
          'id': existing.first[0],
          'name': name,
          'password_hash': PasswordHasher.hash(password),
        },
      );

      stdout.writeln('SUPER_ADMIN berhasil diperbarui: $email');
    } else {
      await pool.execute(
        Sql.named('''
          INSERT INTO users (email, name, password_hash, role, is_active)
          VALUES (@email, @name, @password_hash, 'SUPER_ADMIN', true)
        '''),
        parameters: {
          'email': email,
          'name': name,
          'password_hash': PasswordHasher.hash(password),
        },
      );

      stdout.writeln('SUPER_ADMIN berhasil dibuat: $email');
    }
  } finally {
    await pool.close();
  }
}

String _readPassword() {
  stdout.write('Password baru (minimal 12 karakter): ');

  try {
    stdin.echoMode = false;
    final value = stdin.readLineSync() ?? '';
    stdout.writeln();
    return value;
  } finally {
    stdin.echoMode = true;
  }
}
