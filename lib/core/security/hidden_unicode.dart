const Set<int> _hiddenUnicodePoints = <int>{
  0x200E,
  0x200F,
  0x200B,
  0x200C,
  0x200D,
  0x2060,
  0xFEFF,
  0x00AD,
  0x061C,
  0x034F,
};

const List<({int start, int end})> _hiddenUnicodeRanges =
    <({int start, int end})>[
      (start: 0x202A, end: 0x202E),
      (start: 0x2066, end: 0x2069),
    ];

bool containsHiddenUnicode(String value) {
  for (final codePoint in value.runes) {
    if (_hiddenUnicodePoints.contains(codePoint)) {
      return true;
    }

    for (final range in _hiddenUnicodeRanges) {
      if (codePoint >= range.start && codePoint <= range.end) {
        return true;
      }
    }
  }

  return false;
}

void validateNoHiddenUnicode(String value, {required String path}) {
  if (!containsHiddenUnicode(value)) {
    return;
  }
  throw FormatException('Hidden or bidi Unicode is not allowed at "$path".');
}
