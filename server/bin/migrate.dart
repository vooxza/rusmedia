import 'dart:io';

import 'package:rusmedia_server/src/db.dart';
import 'package:rusmedia_server/src/migrate.dart';

/// Usage: dart run bin/migrate.dart   (reads DATABASE_URL from the environment or .env)
Future<void> main() async {
  var url = Platform.environment['DATABASE_URL'];
  final envFile = File('.env');
  if (url == null && envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      if (line.startsWith('DATABASE_URL='))
        url = line.substring('DATABASE_URL='.length).trim();
    }
  }
  if (url == null || url.isEmpty) {
    stderr.writeln('DATABASE_URL is not set');
    exit(64);
  }
  final pool = createPool(url, maxConnections: 1);
  try {
    final ran = await runMigrations(pool, Directory('migrations'));
    print(
        ran.isEmpty ? 'Database is up to date.' : 'Applied: ${ran.join(', ')}');
  } finally {
    await pool.close();
  }
}
