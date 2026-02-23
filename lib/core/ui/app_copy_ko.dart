class AppCopyKo {
  const AppCopyKo._();

  static String loadFailed(String target) {
    return '$target을 불러오지 못했습니다.';
  }

  static const String emptyImportedReports = '아직 가져온 리포트가 없습니다.';
  static const String emptyFilteredDays = '선택한 필터 결과가 없습니다.';
  static const String emptyReportDays = '리포트에 일자 데이터가 없습니다.';
  static const String actionCanceled = '작업을 취소했습니다.';
  static const String reportImportSuccess = '리포트를 가져왔습니다.';
  static const String reportImportFailed = '리포트를 가져오지 못했습니다.';
  static const String reportImportInvalid = '리포트 형식이 올바르지 않습니다.';
  static const String reportDeleteSuccess = '리포트를 삭제했습니다.';
  static const String reportDeleteAlready = '이미 삭제된 리포트입니다.';
  static const String reportShareSuccess = '리포트를 공유했습니다.';
  static const String reportShareFailed = '리포트 공유에 실패했습니다.';
}
