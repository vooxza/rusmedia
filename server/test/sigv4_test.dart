import 'package:rusmedia_server/src/storage/sigv4.dart';
import 'package:test/test.dart';

void main() {
  test('matches the AWS documented presigned GET example', () {
    // https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
    final signer = SigV4(
      endpoint: Uri.parse('https://s3.amazonaws.com'),
      region: 'us-east-1',
      accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      pathStyle: false,
    );
    final url = signer.presign(
      method: 'GET',
      bucket: 'examplebucket',
      key: 'test.txt',
      expiresSeconds: 86400,
      now: DateTime.utc(2013, 5, 24),
    );
    expect(url, startsWith('https://examplebucket.s3.amazonaws.com/test.txt?'));
    expect(
      url,
      endsWith('X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404'),
    );
  });

  test('encode keeps unreserved characters and escapes the rest', () {
    expect(SigV4.encode('a-b_c.d~E1'), 'a-b_c.d~E1');
    expect(SigV4.encode('a b/c'), 'a%20b%2Fc');
    expect(SigV4.encode('é'), '%C3%A9');
  });

  test('path style puts the bucket in the path and keeps the port in the host', () {
    final signer = SigV4(
      endpoint: Uri.parse('http://localhost:9000'),
      region: 'auto',
      accessKeyId: 'k',
      secretAccessKey: 's',
      pathStyle: true,
    );
    final url = signer.presign(method: 'PUT', bucket: 'b', key: 'x/y.jpg', query: {'partNumber': '1'});
    expect(url, startsWith('http://localhost:9000/b/x/y.jpg?'));
    expect(url, contains('partNumber=1'));
  });

  test('empty key signs a bucket-level request (used to create buckets)', () {
    final signer = SigV4(
      endpoint: Uri.parse('http://localhost:9000'),
      region: 'auto',
      accessKeyId: 'k',
      secretAccessKey: 's',
      pathStyle: true,
    );
    final url = signer.presign(method: 'PUT', bucket: 'my-bucket', key: '');
    expect(url, startsWith('http://localhost:9000/my-bucket?'));
  });
}
