import 'package:rusmedia_server/src/config.dart';
import 'package:test/test.dart';

void main() {
  final valid = {
    'DATABASE_URL': 'postgresql://u:p@localhost:5432/db',
    'S3_ENDPOINT': 'http://localhost:9000',
    'S3_ACCESS_KEY_ID': 'k',
    'S3_SECRET_ACCESS_KEY': 's',
    'S3_BUCKET_ORIGINALS': 'o',
    'S3_BUCKET_DERIVED': 'd',
    'DERIVED_PUBLIC_BASE_URL': 'http://localhost:9000/d',
  };

  test('applies defaults', () {
    final c = Config.fromEnv(valid);
    expect(c.port, 8080);
    expect(c.maxVideoBytes, 6 * 1024 * 1024 * 1024);
    expect(c.uploadPartBytes, 16 * 1024 * 1024);
    expect(c.s3PathStyle, isTrue);
  });

  test('reports every problem at once', () {
    expect(
      () => Config.fromEnv({'S3_ENDPOINT': 'nope'}),
      throwsA(isA<ConfigException>().having((e) => e.problems.length, 'problems', greaterThan(3))),
    );
  });

  test('rejects part sizes below the S3 minimum', () {
    expect(
      () => Config.fromEnv({...valid, 'UPLOAD_PART_BYTES': '1024'}),
      throwsA(isA<ConfigException>()),
    );
  });
}
