import 'dart:convert';
import 'dart:typed_data';

class LimitedUtf8Reader {
  const LimitedUtf8Reader._();

  static Future<String> read(
    Stream<List<int>> stream, {
    required int maxBytes,
    required String path,
  }) async {
    if (maxBytes <= 0) {
      throw FormatException('Expected "$path.maxBytes" to be greater than 0.');
    }

    final bytes = BytesBuilder(copy: false);
    var totalBytes = 0;

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      if (totalBytes > maxBytes) {
        throw FormatException('File exceeds max bytes at "$path".');
      }
      bytes.add(chunk);
    }

    final rawBytes = bytes.takeBytes();
    try {
      return utf8.decode(rawBytes, allowMalformed: false).trim();
    } on FormatException {
      throw FormatException('Expected "$path" to be a valid UTF-8 file.');
    }
  }
}
