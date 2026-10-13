import 'dart:math';

const _extByMime = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
};

String? extensionForMime(String mime) => _extByMime[mime];

/// Storage keys are generated, never derived from user-supplied file names.
String originalKey(
        {required int year,
        required String albumId,
        required String fileId,
        required String mime}) =>
    'originals/$year/$albumId/$fileId.${extensionForMime(mime) ?? 'bin'}';

enum DerivedVariant { thumb, preview, poster }

/// Derived keys include a random segment so URLs are unguessable and rotatable.
String derivedKey(String fileId, DerivedVariant variant,
    {String ext = 'webp', Random? random}) {
  final r = random ?? Random.secure();
  final token =
      List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
  return 'derived/$fileId/$token/${variant.name}.$ext';
}
