# すくすく漢字 · 스쿠스쿠칸지

**하루 5분, 무럭무럭 자라는 한자**

한국인이 익숙한 한국어와 일본어 한자를 연결하며 일본 초등학교 한 학년씩 성장하는 Flutter Android/iOS 앱입니다. 내부 프로젝트명은 `sukusukukanji`입니다.

## 현재 구현: Phase 1–8 (실기기 검증 별도)

- 최초 3장 온보딩, 완료 여부 저장
- 홈 → 순서가 있는 5자 카드 → 3종 퀴즈(기본 8문제) → 정오답 설명 → 결과 → 홈
- 한자음·뜻·대표 음독/훈독·한국어 연결·단어와 출처 표시
- SQLite에 학습 진도, 정답/오답 횟수, 복습 상태, 연속 학습일, 학년 완료 저장
- 재실행 후 진도 복원, 중복 커밋 방지, 저장 실패 시 답안을 유지한 재시도
- 오답 복습, 상세 화면에서 복습 추가, 2회 연속 성공 시 복습 해제
- 내 한자 전체/배운 한자/헷갈리는 한자 필터
- 학년별 진행률, 완료 판정, 다음 학년과 성장 단계 해금, 졸업 축하 확인 저장
- 로딩·오류·빈 상태, 큰 글씨·좁은 화면, 기본 접근성 대응

콘텐츠는 출처를 대조한 **1학년 80자 / 16개 레슨**입니다. 기존 숫자 10자의 ID와 순서를 유지해 이전 진도를 이어갑니다. 80자를 모두 학습하면 1학년 졸업, 2학년 성장 단계와 아이콘 해금으로 이어집니다. 2학년 콘텐츠는 준비 중이며 이전 학년 오답은 계속 복습할 수 있습니다.

- 아이콘 보상: 학년 완료에 따른 해금, 선택 화면, 확인한 모달 재표시 방지, 선택 상태 저장
- 실제 기기 아이콘 변경 실패 시 선택을 보존하고, 저장 실패 시 지원 서비스의 이전 아이콘 복원
- 새싹부터 나무까지 6개 식물 아이콘과 재현 가능한 생성 도구, 기본 Android/iOS 새싹 런처 이미지
- 전체 읽기와 원본 사전 뜻을 퀴즈의 유효 읽기·유사 뜻 오답 제외에 활용

**남은 작업:** 실제 Android/iOS alternate launcher icon 연결과 실기기 확인. `AppIconService` 계약과 MethodChannel 경계를 만들었지만 네이티브 핸들러는 아직 없습니다. 현재 선택 UI는 선택 상태를 저장하며 실제 기기 아이콘을 바꿨다고 표시하지 않습니다. Android SDK/Xcode가 없어 APK/IPA 및 OS 저장 플러그인 실기기 검증도 하지 못했습니다. 일부 한자에는 검증된 예시 단어만 제공하며, 빈 단어·연결 섹션은 숨깁니다. 후속 콘텐츠 작업에서 단어·문장을 사전 대조하고 전문가 감수를 확장해야 합니다. 서버·로그인·AI·TTS는 추가하지 않았습니다.

## 실행

최소 SDK: **Flutter 3.47.0 / Dart 3.13.3**. 패치 버전 업데이트 없이 Dart 3.13.3 환경에서 의존성을 받을 수 있도록 요구조건을 낮췄습니다. 자동 검증 환경은 Flutter 3.47.6 stable / Dart 3.13.5이며, Dart 3.13.3에서 직접 실행한 결과는 아직 없습니다. `pubspec.lock`을 유지합니다.

```sh
flutter pub get
flutter run
```

Android는 Android SDK와 기기/에뮬레이터, iOS는 macOS·Xcode와 기기/시뮬레이터가 필요합니다. 배포 전 `com.example.sukusukukanji` 식별자와 서명을 확정해야 합니다.

```sh
dart format .
flutter analyze
flutter test
flutter build bundle --debug --no-pub
```

읽기 전용 사용자 홈을 가진 현재 클라우드 환경의 검증 설정:

```sh
export PATH="/workspace/.tools/flutter/bin:$PATH"
export PUB_CACHE=/workspace/.cache/pub
export XDG_CONFIG_HOME=/workspace/.cache/config
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.cache/dart-analyzer
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true

dart --suppress-analytics format .
flutter analyze
flutter test
flutter build bundle --target-platform=linux-x64 --debug --no-pub
```

통계 비활성화는 Dart/Flutter 도구가 읽기 전용 홈에 파일을 만들지 않도록 합니다. 현재 환경에서는 Android SDK가 없어 Linux 대상의 코드·asset 번들만 확인할 수 있습니다. Linux 앱을 제품 대상으로 추가한 것은 아닙니다. SQLite FFI 테스트의 native hook에도 `DASH__SUPPRESS_ANALYTICS`가 필요합니다. SDK·패키지 다운로드와 테스트 VM 로컬 소켓은 실행 도구의 네트워크 권한이 필요하지만, 앱은 런타임 네트워크 요청을 하지 않습니다.

## 사용 규칙

- 새 학습은 아직 배우지 않은 첫 레슨에서 최대 5자를 선택합니다. 같은 날 더 배울 수도 있습니다.
- **카드와 퀴즈를 끝내고 저장에 성공해야** 배운 한자로 기록됩니다. 중간 나가기와 앱 강제 종료 시 미완료 세션은 재개하지 않으며, 기존 완료 기록은 유지됩니다.
- 한 문제라도 틀린 한자는 복습 대상입니다. 그 한자의 모든 문제를 맞힌 복습 세션을 2회 연속 완료하면 해제됩니다. 중간에 틀리면 연속 성공은 0으로 돌아갑니다.
- 연속 학습일은 세션 완료 시 사용자의 로컬 달력 날짜로 계산합니다. 같은 날 여러 세션은 1일입니다.
- 졸업은 모든 필수 한자를 한 번 학습하는 기준이며, 오답이 없어야 한다는 뜻은 아닙니다. 진급 후에도 이전 학년 오답은 복습할 수 있습니다.
- 기록은 이 기기에만 저장합니다. 앱 삭제 시 기록이 사라질 수 있습니다. 클라우드 동기화와 백업은 없습니다.

## 구조

```text
lib/
  app/                   # bootstrap, AppController, Navigator, theme
  data/
    models/              # 콘텐츠, 학년, 진도, 세션, 퀴즈, 설정
    repositories/        # 콘텐츠 구현과 사용자 저장소 계약
    services/            # 세션 선정, 퀴즈 생성, 진도/복습/학년 규칙
    storage/             # SQLite, preferences, 데이터 매핑
  features/
    onboarding/ home/ study/ quiz/ kanji/ grades/ settings/ app_icon/
  widgets/               # 한자 콘텐츠, 식물, 공통 레이아웃
assets/
  data/grades.json
  data/kanji/grade1.json
  icons/grade1.png … grade6.png
tool/export_icons_test.dart # flutter test tool/export_icons_test.dart
test/                    # 도메인, 실제 SQLite, 앱 controller, 화면 흐름
```

[구현 설계](docs/architecture.md) · [콘텐츠 검증](docs/content-verification.md) · [검증 기록과 수동 체크](docs/validation.md) · [콘텐츠 저작권 고지](THIRD_PARTY_NOTICES.md)
