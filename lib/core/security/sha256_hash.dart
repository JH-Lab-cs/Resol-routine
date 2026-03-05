import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

String computeSha256Hex(String value) {
  final bytes = utf8.encode(value);
  return crypto.sha256.convert(bytes).toString();
}
