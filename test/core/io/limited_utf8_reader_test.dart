import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/io/limited_utf8_reader.dart';

void main() {
  group('readUtf8WithByteLimit', () {
    test('decodes valid utf8 payload within limit', () async {
      final payload = utf8.encode('  {"ok":true}  ');

      final output = await readUtf8WithByteLimit(
        stream: Stream<List<int>>.fromIterable(<List<int>>[payload]),
        maxBytes: 64,
        path: 'test.file',
      );

      expect(output, '{"ok":true}');
    });

    test('throws FormatException when stream exceeds max bytes', () async {
      final chunkA = utf8.encode('12345');
      final chunkB = utf8.encode('67890');

      await expectLater(
        () => readUtf8WithByteLimit(
          stream: Stream<List<int>>.fromIterable(<List<int>>[chunkA, chunkB]),
          maxBytes: 9,
          path: 'test.file',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for invalid utf8 bytes', () async {
      const invalidUtf8 = <int>[0xC3, 0x28];

      await expectLater(
        () => readUtf8WithByteLimit(
          stream: Stream<List<int>>.fromIterable(<List<int>>[invalidUtf8]),
          maxBytes: 16,
          path: 'test.file',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
