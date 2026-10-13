import 'dart:typed_data';

enum FileKind { image, video }

class AllowedFormat {
  const AllowedFormat(this.mime, this.extensions, this.kind);
  final String mime;
  final List<String> extensions;
  final FileKind kind;
}

const allowedFormats = <AllowedFormat>[
  AllowedFormat('image/jpeg', ['jpg', 'jpeg'], FileKind.image),
  AllowedFormat('image/png', ['png'], FileKind.image),
  AllowedFormat('image/webp', ['webp'], FileKind.image),
  AllowedFormat('video/mp4', ['mp4'], FileKind.video),
  AllowedFormat('video/quicktime', ['mov'], FileKind.video),
  AllowedFormat('video/webm', ['webm'], FileKind.video),
];

String extensionOf(String fileName) {
  final i = fileName.lastIndexOf('.');
  return i == -1 ? '' : fileName.substring(i + 1).toLowerCase();
}

/// Declared-metadata check: file name extension and MIME type agree and are allowed.
AllowedFormat? matchDeclaredFormat(String fileName, String mime) {
  final ext = extensionOf(fileName);
  final m = mime.toLowerCase();
  for (final f in allowedFormats) {
    if (f.mime == m && f.extensions.contains(ext)) return f;
  }
  return null;
}

bool _ascii(Uint8List b, int start, String s) {
  if (b.length < start + s.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[start + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

/// Content check: inspects the first bytes of the stored file, ignoring what the client claimed.
String? sniffMime(Uint8List head) {
  if (head.length >= 3 && head[0] == 0xff && head[1] == 0xd8 && head[2] == 0xff)
    return 'image/jpeg';
  const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (head.length >= 8 &&
      List.generate(8, (i) => head[i] == png[i]).every((x) => x))
    return 'image/png';
  if (_ascii(head, 0, 'RIFF') && _ascii(head, 8, 'WEBP')) return 'image/webp';
  if (head.length >= 4 &&
      head[0] == 0x1a &&
      head[1] == 0x45 &&
      head[2] == 0xdf &&
      head[3] == 0xa3) {
    return 'video/webm'; // EBML
  }
  if (_ascii(head, 4, 'ftyp') && head.length >= 12) {
    return _ascii(head, 8, 'qt  ') ? 'video/quicktime' : 'video/mp4';
  }
  return null;
}

/// MP4 and MOV share the ISO base media container, so either sniff result satisfies either declaration.
bool mimeCompatible(String declared, String sniffed) {
  if (declared == sniffed) return true;
  const iso = {'video/mp4', 'video/quicktime'};
  return iso.contains(declared) && iso.contains(sniffed);
}
