class AppCopyKo {
  const AppCopyKo._();

  static String loadFailed(String target) {
    return '$target을 불러오지 못했습니다.';
  }

  static String saveFailed(String target) {
    return '$target 저장에 실패했습니다.';
  }

  static String importSizeExceeded({required String maxMb}) {
    return '파일이 너무 큽니다(최대 ${maxMb}MB).';
  }

  static const String emptyData = '데이터가 없습니다.';
  static const String emptyWrongNotes = '아직 오답이 없습니다.';
  static const String emptyTodayVocabulary = '오늘의 단어가 없습니다.';
  static const String emptyMyVocabulary = '나만의 단어가 없습니다.';
  static const String emptyImportedReports = '아직 가져온 리포트가 없습니다.';
  static const String emptyFilteredDays = '선택한 필터 결과가 없습니다.';
  static const String emptyReportDays = '리포트에 일자 데이터가 없습니다.';
  static const String actionCanceled = '작업을 취소했습니다.';
  static const String reportImportSuccess = '리포트를 가져왔습니다.';
  static const String reportImportFailed = '리포트를 가져오지 못했습니다.';
  static const String reportImportInvalid = '리포트 형식이 올바르지 않습니다.';
  static const String reportDeleteSuccess = '리포트를 삭제했습니다.';
  static const String reportDeleteFailed = '리포트 삭제에 실패했습니다.';
  static const String reportDeleteAlready = '이미 삭제된 리포트입니다.';
  static const String reportShareSuccess = '리포트를 공유했습니다.';
  static const String reportShareFailed = '리포트 공유에 실패했습니다.';
  static const String settingsSaveFailed = '설정 저장에 실패했습니다.';
  static const String birthDateInvalid = '생년월일을 YYYY-MM-DD 형식으로 입력해 주세요.';
  static const String settingsCopiedEmail = '문의 메일 주소를 복사했어요.';
  static const String logoutSuccess = '로그아웃되었습니다.';
  static const String withdrawSuccess = '탈퇴 처리되었습니다.';
  static const String todaySessionDeleteSuccess = '오늘 세션을 삭제했습니다.';
  static const String vocabSaved = '단어를 저장했습니다.';
  static const String vocabUpdated = '단어를 수정했습니다.';
  static const String vocabDeleted = '단어를 삭제했습니다.';
  static const String vocabAlreadyDeleted = '이미 삭제된 단어입니다.';
  static const String vocabDeleteFailed = '단어 삭제에 실패했습니다.';
  static const String vocabSaveFailed = '단어 저장에 실패했습니다.';
  static const String wrongTagRequired = '오답 태그를 선택해 주세요.';
  static const String quizLoadFailed = '퀴즈를 불러오지 못했습니다.';
  static const String vocabQuizLoadFailed = '단어 시험을 불러오지 못했습니다.';
  static const String vocabQuizSaveFailed = '단어시험 결과 저장에 실패했습니다.';
  static const String wrongNoteOpenResult = '결과 보기';
  static const String mockExamWeekly = '주간 모의고사';
  static const String mockExamMonthly = '월간 모의고사';
  static const String emptyMockHistory = '아직 모의고사 기록이 없습니다.';
  static const String mockHistoryDeleteAction = '삭제';
  static const String mockHistoryDeleteCancel = '취소';
  static const String mockHistoryDeleteConfirm = '삭제';
  static const String mockHistoryDeleteSuccess = '모의고사 기록을 삭제했습니다.';
  static const String mockHistoryDeleteFailed = '모의고사 기록 삭제에 실패했습니다.';
  static const String mockHistoryDeleteAlready = '이미 삭제된 모의고사 기록입니다.';
  static const String parentInviteCodeInvalid = '초대 코드는 숫자 6자리여야 합니다.';
  static const String parentChildAdded = '자녀를 추가했습니다.';
  static const String parentChildAddFailed = '자녀를 추가하지 못했습니다.';

  static String mockHistoryDeleteTitle(String examLabel) {
    return '$examLabel 기록 삭제';
  }

  static String mockHistoryDeleteMessage({
    required String examLabel,
    required String periodKey,
  }) {
    return '$examLabel $periodKey 기록을 삭제할까요?\n삭제하면 복구할 수 없습니다.';
  }

  static String wrongNoteMockMeta({
    required String examLabel,
    required String periodKey,
    required String completedDate,
    required String trackLabel,
  }) {
    return '$examLabel · $periodKey · $completedDate · $trackLabel';
  }
}
