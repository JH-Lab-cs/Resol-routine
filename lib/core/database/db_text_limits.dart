class DbTextLimits {
  const DbTextLimits._();

  static const int idMax = 80;
  static const int localeMax = 16;
  static const int titleMax = 150;
  static const int checksumMax = 150;

  static const int typeTagMax = 16;
  static const int promptMax = 2000;
  static const int whyCorrectKoMax = 4000;

  static const int lemmaMax = 120;
  static const int meaningMax = 400;
  static const int displayNameMax = 40;
  static const int reportSourceMax = 120;
  static const int reportPayloadMax = 2000000;
  static const int reportImportMaxBytes = 10 * 1024 * 1024;
  static const int reportImportRawMaxChars = reportPayloadMax * 3;
}
