import 'dart:io';

import 'package:postgres/postgres.dart';

/// Applies `migrations/*.sql` in filename order, once each, each inside a transaction.
Future<List<String>> runMigrations(Pool<void> pool, Directory dir) async {
  await pool.execute('''
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  ''');

  final applied = (await pool.execute('SELECT name FROM schema_migrations'))
      .map((r) => r[0] as String)
      .toSet();

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final ran = <String>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (applied.contains(name)) continue;
    final sql = await file.readAsString();
    await pool.runTx((tx) async {
      // Simple query mode allows several statements in one file.
      await tx.execute(sql, queryMode: QueryMode.simple);
      await tx.execute(
          Sql.named('INSERT INTO schema_migrations (name) VALUES (@name)'),
          parameters: {'name': name});
    });
    ran.add(name);
  }
  return ran;
}
