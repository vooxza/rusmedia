import 'dart:io';

import 'package:rusmedia_server/src/app.dart';
import 'package:rusmedia_server/src/config.dart';
import 'package:rusmedia_server/src/db.dart';
import 'package:rusmedia_server/src/storage/object_storage.dart';
import 'package:rusmedia_server/src/storage/s3_storage.dart';
import 'package:shelf/shelf_io.dart' as io;

Map<String, String> _loadEnv() {
  final env = <String, String>{...Platform.environment};
  final file = File('.env');

  if (file.existsSync()) {
    for (final raw in file.readAsLinesSync()) {
      final line = raw.trim();

      if (line.isEmpty || line.startsWith('#')) continue;

      final i = line.indexOf('=');
      if (i <= 0) continue;

      // Real environment variables win over the .env file.
      env.putIfAbsent(
        line.substring(0, i).trim(),
        () => line.substring(i + 1).trim(),
      );
    }
  }

  return env;
}

Future<void> main() async {
  final Config config;

  try {
    config = Config.fromEnv(_loadEnv());
  } on ConfigException catch (e) {
    stderr.writeln(e);
    exit(64);
  }

  final pool = createPool(config.databaseUrl);
  final storage = S3Storage(config);

  if (config.autoCreateBuckets) {
    try {
      await storage.ensureBucket(Bucket.originals);
      await storage.ensureBucket(
        Bucket.derived,
        publicRead: true,
      );

      print('Storage buckets are ready.');
    } catch (e) {
      stderr.writeln(
        'Could not prepare storage buckets: $e\n'
        'Is the storage container running? Try: docker compose ps',
      );

      await pool.close();
      exit(70);
    }
  }

  final handler = buildApp(
    config: config,
    pool: pool,
    storage: storage,
  );

  final server = await io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
  );

  print('RUSMEDIA server listening on :${server.port}');

  // Handle SIGTERM only on non-Windows platforms.
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      print('\nShutting down RUSMEDIA server...');

      await server.close(force: false);
      await pool.close();

      exit(0);
    });
  }

  // Handle Ctrl + C.
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down RUSMEDIA server...');

    await server.close(force: false);
    await pool.close();

    exit(0);
  });
}
