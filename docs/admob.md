# AdMob 준비와 실행

2026-10-11 기준 `google_mobile_ads 9.1.0`을 추가했습니다. 공식 google.dev 게시 패키지이며 Dart >=3.10.0, Flutter >=3.38.1을 요구합니다. 프로젝트의 Dart ^3.13.3 / Flutter >=3.47.0과 호환됩니다. Android 최소 SDK는 플러그인 요구에 맞게 24로 설정했습니다. iOS 프로젝트는 기존 최소 15.0을 유지합니다.

## 구현한 이용 정책

- **초등학교 1학년은 80자 / 16개 레슨 전체 무료 체험**입니다. 하루 레슨 제한과 이용권 차감, 보상형 광고 안내, 레슨 완료 전면 광고가 없습니다. 하단 배너는 유지합니다.
- **2학년 이후**는 기기 현지 날짜 기준 하루 **새 레슨 2개**를 무료로 엽니다.
- 학습을 처음 시작할 때 횟수를 사용합니다. 열린 레슨 ID를 저장하므로 중단·앱 종료 후 같은 레슨을 다시 시작해도 추가 차감하지 않습니다.
- 이후 추가 새 레슨은 **보상형 광고 완료 보상 1회당 이용권 1개**로 엽니다.
- 무료 횟수를 먼저 사용하고, 그 뒤 이용권을 사용합니다. 남은 이용권은 다음 날에도 유지합니다.
- 완료 레슨 복습·오답 복습은 횟수 제한과 전면 광고 없이 제공합니다.
- 2학년 이후 신규 레슨 결과를 저장한 뒤 전면 광고를 표시합니다. 이미 준비된 광고만 표시하며, 광고 로딩을 기다렸다가 화면 전환 후 늦게 띄우지 않습니다. 보상 이용권으로 연 레슨에는 전면 광고를 생략하고, 전면형 광고끼리는 최소 90초 간격을 둡니다.
- 홈·학습·내 한자 탭의 하단 탐색 바 위에 적응형 배너를 배치합니다. 학습 카드·퀴즈·결과 화면에는 배너를 표시하지 않습니다. 로딩 실패 시 빈 광고 공간을 남기지 않습니다.
- 광고 길이와 닫기 가능 시점은 AdMob과 광고 소재가 결정합니다. 앱에서 '가장 긴 광고'를 강제하거나 자체 타이머로 보상을 지급하지 않습니다.
- **초등 전체 해금 5,500원 결제는 아직 구현하지 않았습니다.** `CourseEntitlements`의 `hasUnlimitedAccess(grade)`와 `removesAds(grade)`에 추후 검증된 스토어 구매를 연결합니다. 현재 모든 실제 사용자는 미구매이며 결제 버튼·가짜 구매 성공·로컬 구매 스위치는 없습니다. 중학교까지 혜택이 확장되지 않도록 상품 범위를 구분해야 합니다.

## Android Studio / 일반 테스트 실행

```bash
flutter pub get
flutter run
```

Android/iOS debug·profile 실행은 기본으로 Google 공식 테스트 앱 ID·광고 단위 ID를 사용합니다. Android Studio에서는 Flutter 실행 구성을 선택해 `lib/main.dart`를 실행합니다. 네이티브 플러그인을 추가했으므로 기존 실행을 완전히 종료한 뒤 다시 실행해야 합니다. Hot Reload만으로는 적용되지 않습니다.

Google 테스트 앱 ID에는 개발자의 UMP 메시지가 설정되어 있지 않으므로 **기본 테스트 모드에 한해서 UMP 설정 없이 공식 데모 광고만 요청**합니다. 라이브 모드는 항상 UMP를 거치며 이 예외를 적용하지 않습니다. 테스트 광고는 수익을 발생시키지 않습니다.

```bash
flutter run --dart-define=ADMOB_MODE=test
flutter run --dart-define=ADMOB_MODE=off
```

`off`는 광고와 무료 레슨 제한을 모두 비활성화해 콘텐츠/UI 개발에 사용합니다. 웹·데스크톱에서도 항상 비활성화됩니다. 일반 release 빌드의 기본값도 `off`입니다. 실제 광고는 명시적으로 `live`를 설정해야 합니다. debug에서 `live`를 요청하거나 실제 광고 단위 ID 세 개가 누락되면 설정 오류를 냅니다.

## 실제 광고 ID 연결

AdMob에서 Android/iOS 앱을 각각 등록하고, 플랫폼마다 배너·전면·보상형 광고 단위를 하나씩 만듭니다. 앱 ID는 `~`, 광고 단위 ID는 `/`를 포함하므로 서로 바꿔 넣지 마세요.

### Android 앱 ID

`android/app/build.gradle.kts`의 `ADMOB_APP_ID` Gradle 속성이 Manifest의 `com.google.android.gms.ads.APPLICATION_ID`에 연결됩니다. 기본값은 Google 샘플 앱 ID입니다. 로컬 `android/gradle.properties`에 실제 ID를 설정하거나 환경 변수로 전달합니다.

PowerShell 예시(값은 본인 계정에서 발급한 것으로 교체):

```powershell
$env:ORG_GRADLE_PROJECT_ADMOB_APP_ID = '실제 Android 앱 ID'
flutter build appbundle --release --dart-define=ADMOB_MODE=live --dart-define=ADMOB_BANNER_ID='실제 Android 배너 ID' --dart-define=ADMOB_INTERSTITIAL_ID='실제 Android 전면 ID' --dart-define=ADMOB_REWARDED_ID='실제 Android 보상형 ID'
```

### iOS 앱 ID

`ios/Flutter/AdMob.xcconfig`의 `ADMOB_APP_ID`를 실제 iOS 앱 ID로 교체합니다. Debug/Release xcconfig와 Info.plist가 이 값을 사용합니다. macOS에서 같은 세 `--dart-define`에 **iOS** 광고 단위 ID를 전달하여 빌드합니다. 현재 번들의 앱 ID, signing과 AdMob 앱 등록을 출시 대상에 맞게 함께 설정해야 합니다.

공식 iOS 안내에 맞는 SKAdNetwork 항목, 앱의 실제 추적 방식에 따른 ATT 처리, 스토어 개인정보 공개와 개인정보처리방침은 실배포 전에 확인해야 합니다. 현재 코드에는 ATT 요청이나 자체 사용자 추적 코드가 없습니다. ATT 미허용 상태에서도 가능한 광고 제공 방식은 기기 테스트로 확인해야 합니다.

### UMP 동의 / 개인정보 선택

실제 AdMob 앱의 Privacy & messaging에서 필요한 메시지와 개인정보처리방침 URL을 설정합니다. live 모드에서는 실행 시 동의 정보 갱신 → 필요한 동의 화면 → `canRequestAds()` 확인 → Mobile Ads 초기화/광고 요청 순서로 진행합니다. 요청이 허용되지 않거나 오류가 나면 무료 학습은 계속 사용할 수 있으며 광고는 요청하지 않습니다.

`getPrivacyOptionsRequirementStatus()`가 required이면 앱 안내에 **광고 개인정보 선택** 메뉴가 표시됩니다. 동의 설정을 다시 열 때 캐시 광고와 배너를 내려두고, 갱신된 요청 가능 여부를 다시 확인합니다.

실제 앱 ID와 UMP 메시지를 설정한 뒤 공식 테스트 광고 단위로 동의 동작도 확인하려면:

```bash
flutter run --dart-define=ADMOB_MODE=test --dart-define=ADMOB_TEST_CONSENT=true
```

지역별 동의 화면 검증에는 Google 문서의 UMP 테스트 기기/디버그 지역 설정도 적용해야 합니다. 개인정보처리방침은 앱 운영자가 제공해야 하며 이 저장소가 임의의 URL을 만들지 않습니다.

## 저장과 실패 처리

SQLite schema v3의 `learning_access`에 날짜, 무료 사용 횟수, 이용권, 열린 레슨, 보상 이용권으로 연 레슨, 처리한 보상 receipt를 저장합니다. v1/v2 데이터는 진도·즐겨찾기·학년·중복 저장 방지 기록을 유지한 채 마이그레이션됩니다. 학습 저장과 같은 repository 트랜잭션을 사용합니다.

기존 1학년 이용 기록도 그대로 보존합니다. 1학년 무료 체험은 해당 기록의 횟수·이용권을 읽어 제한하거나 소비하지 않으며 별도 DB 마이그레이션은 필요하지 않습니다.

보상은 `onUserEarnedReward` 콜백에서 즉시 저장을 시작합니다. 광고를 닫았다는 이유만으로 지급하지 않으며 동일 receipt는 한 번만 처리합니다. 저장 실패 시 현재 실행 중인 앱에서 '보상 저장 다시 시도'를 제공해 광고를 다시 보지 않게 합니다. 저장 자체가 실패한 상태에서 프로세스까지 종료된 경우에는 서버 영수증이 없으므로 보상 복구를 보장할 수 없습니다. 이 제한은 단순히 광고를 정상 완료·저장한 뒤 재실행하는 경우와 다릅니다.

현재는 서버·로그인이 없는 로컬 구조입니다. 날짜를 과거로 돌리는 경우 무료 횟수를 재지급하지 않지만, 미래로의 시계 조작·앱 데이터 삭제·클라이언트 변조까지 막는 구조는 아닙니다. 서버 측 광고 보상 검증(SSV)과 여러 기기 간 이용권 동기화는 구현하지 않았습니다.

## 기기에서 남은 확인

1. 실제 Android/iOS에서 Test Ad 표시가 있는 배너·전면·보상형 광고 확인.
2. 1학년에서 같은 날 세 레슨 이상 학습해도 제한·보상 안내·전면 광고가 없는지 확인. 2학년 이후 콘텐츠 연결 시 두 레슨 이후 보상 안내, 중도 닫기, 이용권, 광고 실패/오프라인 확인.
3. 레슨 중 앱 종료 후 재개, 날짜 변경, 사용하지 않은 이용권 재실행 복원 확인.
4. 2학년 이후 저장 완료 후 전면 광고, 보상형 직후 전면 광고 생략, 배너와 하단 제스처 영역 확인.
5. UMP 필요한 지역/불필요한 지역, 동의 재설정, background/resume, 큰 글씨 확인.
6. 실배포 ID·서명·스토어 개인정보 안내 설정. 5,500원 상품은 별도 인앱 결제 구현과 sandbox 구매/복원/환불 검증 필요.

## 공식 참고

- SDK: https://pub.dev/packages/google_mobile_ads
- 초기 설정: https://developers.google.com/admob/flutter/quick-start
- 테스트 광고: https://developers.google.com/admob/flutter/test-ads
- 보상형: https://developers.google.com/admob/flutter/rewarded
- 전면: https://developers.google.com/admob/flutter/interstitial
- 동의/UMP: https://developers.google.com/admob/flutter/privacy

2학년 이후 학습 콘텐츠는 아직 준비 중입니다. 광고 제한 회귀 테스트는 검증된 한자 정보를 테스트 안에서만 2학년 세션으로 재배치한 fixture를 사용하며 실제 앱 콘텐츠 배정을 변경하지 않습니다.
