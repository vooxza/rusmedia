import 'dart:typed_data';

enum Bucket { originals, derived }

class UploadedPart {
  const UploadedPart(this.partNumber, this.etag);
  final int partNumber;
  final String etag;
}

class ObjectHead {
  const ObjectHead({required this.size, this.contentType});
  final int size;
  final String? contentType;
}

/// The only abstraction the rest of the server uses to talk to object storage.
abstract class ObjectStorage {
  Future<String> createMultipartUpload(String key, String contentType);
  String presignUploadPart(String key, String uploadId, int partNumber,
      {int ttlSeconds = 3600});
  Future<List<UploadedPart>> listParts(String key, String uploadId);
  Future<void> completeMultipartUpload(
      String key, String uploadId, List<UploadedPart> parts);
  Future<void> abortMultipartUpload(String key, String uploadId);

  /// Creates the bucket if it does not exist. With [publicRead] anyone may download its objects
  /// (used for the derived bucket that holds thumbnails and previews). Safe to call repeatedly.
  Future<void> ensureBucket(Bucket bucket, {bool publicRead = false});

  Future<ObjectHead?> head(Bucket bucket, String key);

  /// Inclusive byte range, used for magic-byte sniffing without downloading the file.
  Future<Uint8List> getRange(Bucket bucket, String key, int start, int end);
  Future<void> put(
      Bucket bucket, String key, Uint8List body, String contentType,
      {String? cacheControl});
  Future<void> delete(Bucket bucket, List<String> keys);

  /// Short-lived signed GET. Pass [downloadName] to force an attachment download.
  String presignGet(Bucket bucket, String key,
      {int ttlSeconds = 300, String? downloadName});

  /// Public CDN URL for derived (thumbnail/preview/poster) objects.
  String derivedUrl(String key);
}
