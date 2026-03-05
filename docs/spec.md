# Resol Routine Spec (Source of Truth)

## 0. 목적
- 중3(M3)~고3(H3) 대상 “매일 훈련” 앱
- 오늘의 6문제 = 듣기 3 + 독해 3 (고정)
- 단어는 SRS 기반 별도 플로우(questions 테이블에 VOCAB 없음)

## 1. Track
- M3 = 중3
- H1 = 고1
- H2 = 고2
- H3 = 고3

## 2. Skills
- LISTENING, READING만 questions에 존재
- 단어는 vocab_master/vocab_srs_state로 동적 생성 (A4에서 구현)

## 3. 오늘의 6문제 규칙 (Daily Session)
- 입력: (dayKey=yyyymmdd, track)
- 출력: 고정 순서 [LISTENING, LISTENING, LISTENING, READING, READING, READING]
- 결정론: 같은 dayKey+track이면 항상 동일한 문제 세트 (재추첨 금지)
- 세션은 DB에 저장되어 Resume 가능해야 함

## 4. 오답 이유 태그 (고정 enum)
- VOCAB
- EVIDENCE
- INFERENCE
- CARELESS
- TIME

## 5. DB 불변 규칙
### 5.1 questions
- skill ∈ {LISTENING, READING}
- LISTENING: script_id NOT NULL AND passage_id IS NULL
- READING: passage_id NOT NULL AND script_id IS NULL
- options는 A..E 5개 고정
- answerKey ∈ {A,B,C,D,E}

### 5.2 daily sessions
- day_key는 yyyymmdd
- UNIQUE(day_key, track)
- daily_session_items(또는 동등 구조)로 session 내 문제ID/순서를 저장

### 5.3 JSON 컬럼
- 앱 코드에서 jsonDecode/jsonEncode를 UI 레벨에 두지 않는다.
- Drift TypeConverter/Repository 파서로 강타입 유지.

## 6. Content Pack (assets)
- 모든 ID는 pack 내에서 unique
- evidenceSentenceIds는 실제 문장 ID에 존재해야 한다.
- ttsPlan 범위는 parser 규칙을 따른다.
- Starter pack은 개발용이며, 최소 조건:
  - 각 track(M3/H1/H2/H3)에 대해 LISTENING >= 3, READING >= 3

## 7. 보안/품질 게이트 (모든 PR)
- python3 tool/security/check_bidi.py (must pass)
- dart analyze (must pass)
- flutter test (must pass)

## 8. 언어 정책 (UI/콘텐츠)
- 앱 UI 문자열(버튼/메뉴/라벨/안내 카피)은 한국어로 작성한다.
- 문제 콘텐츠(문항 prompt, 지문/스크립트, 선택지)는 영어로 작성한다.
- 해설 필드 `whyCorrectKo`, `whyWrongKo`는 한국어로 작성한다.
