# Android Google 로그인과 진도 백업

스쿠스쿠칸지용 별도 Supabase 프로젝트를 권장합니다. 현재 저장소에 실제 프로젝트 주소나 키는 없으며 원격 DB/함수도 배포하지 않았습니다. `SUPABASE_URL`과 `SUPABASE_PUBLISHABLE_KEY`가 없으면 기존 로컬 학습은 그대로 동작하고 계정 화면에는 준비 중으로 표시합니다. iOS 계정 연결은 현재 활성화하지 않습니다.

## 서비스 선택

- **Supabase Auth + PostgreSQL**: Google 인증, 사용자별 백업, RLS를 한곳에서 처리합니다. Flutter는 Supabase에 직접 연결합니다. 별도 Python API나 Cloudflare Worker를 거칠 필요가 없습니다.
- **Cloudflare**: DNS, 앱 소개/도움말, 개인정보처리방침, 계정 삭제 요청 웹페이지를 운영하는 용도로 적합합니다. 앱의 진도 저장에는 필수가 아닙니다.
- **Firebase Auth + Firestore**도 구현 가능합니다. 현재는 SQLite가 오프라인 저장을 이미 담당하므로 Firestore 오프라인 기능을 위해 저장 구조를 바꿀 필요가 적고, 운영자가 경험 있는 Supabase로 시작하는 편을 권장합니다.
- 직접 FastAPI를 구축하면 인증 검증·권한·DB·백업·운영도 관리해야 합니다. 현 요구에서는 이 복잡도가 필요하지 않습니다.

## 1. Supabase 준비

1. 스쿠스쿠칸지 전용 프로젝트를 생성합니다. 기존 morak 데이터/사용자와 분리합니다.
2. SQL Editor 또는 Supabase CLI migration으로 `supabase/migrations/202610120001_progress_backup.sql`을 적용합니다.
3. Auth → Providers → Google을 활성화합니다.
4. 프로젝트 HTTPS URL과 **publishable key (`sb_publishable_…`)**를 확인합니다. service-role/secret key는 절대 앱에 넣지 않습니다. 현재 어댑터는 실수로 비밀 키를 포함하지 않도록 publishable key만 허용합니다.
5. Auth → URL Configuration → Redirect URLs에 정확히 `app.sukusukukanji://login-callback`을 추가합니다.

`supabase_flutter 2.18.3`은 Dart >=3.9 / Flutter >=3.35를 요구하며 현재 Dart ^3.13.3 / Flutter >=3.47.0과 호환됩니다. 기존 shared_preferences를 재사용합니다. 별도 상태 관리·라우팅·Google 로그인 패키지는 추가하지 않습니다.

## 2. Google OAuth 준비

Google Cloud Console에서 프로젝트, OAuth 동의 화면/브랜딩/개인정보처리방침, OAuth 클라이언트를 준비합니다. 이 구현은 브라우저 + Supabase PKCE 방식이므로 **웹 애플리케이션 유형 OAuth Client**를 사용합니다.

- Google Authorized redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback` (실제 Supabase provider 화면의 callback URL을 사용)
- Google Client ID / Client Secret: Supabase의 Google provider 설정에만 입력
- 앱으로 최종 복귀: `app.sukusukukanji://login-callback`
- OAuth 앱이 테스트 상태이면 Google 테스트 사용자로 로그인 확인 후 배포 상태를 설정

Android Manifest에는 VIEW/BROWSABLE callback 필터를 등록했습니다. Flutter 기본 딥링크 처리를 끄고 supabase_flutter/app_links가 인증 콜백을 처리합니다. 로그인 성공 시 앱으로 돌아오며, 취소한 경우 다시 연결할 수 있습니다. 현재 Android 네이티브 Credential Manager 방식은 사용하지 않습니다.

## 3. 실행

PowerShell:

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_REPLACE
```

Android Studio Flutter Run Configuration의 Additional run args에도 같은 두 `--dart-define`을 넣습니다. 새 네이티브 플러그인이 있으므로 앱을 완전히 재시작해야 합니다. Release 빌드에도 값을 전달해야 합니다. 공개 키가 앱에 포함되는 것은 정상이며 데이터 보호는 RLS와 인증된 RPC가 담당합니다.

## 4. 백업 동작

설정 → **계정과 진도 백업** → Google 계정 연결에서 시작합니다.

- 처음 연결하면 기기 기록을 업로드하거나 클라우드 기록을 복원할지 선택합니다. 계정이 달라졌을 때도 자동으로 이전 사람의 기록을 업로드하지 않습니다.
- 백업 시작 이후 학습 결과·복습 추가·즐겨찾기·졸업 확인 변경을 SQLite에 먼저 저장하고 자동 백업합니다. 짧은 연속 변경은 합쳐서 전송합니다.
- 오프라인/서버 오류는 학습 저장을 취소하지 않습니다. 앱 재실행, foreground 복귀, 다음 학습 변경, 수동 다시 시도에서 백업을 재시도합니다.
- 백업이 다른 기기에서 바뀌면 덮어쓰기를 중단합니다. 백업 확인 후 복원 또는 이 기기 기록으로 교체를 선택합니다. 여러 기기의 기록을 자동 병합하는 기능은 아닙니다.
- 복원에는 명시적 확인이 필요하며 현재 기기의 학습 기록을 교체합니다. 복원 중 기기 기록이 바뀌면 복원을 취소합니다.
- 로그아웃해도 기기 기록은 유지합니다. Google 계정과 Google Play 구매 계정은 서로 다를 수 있으며 진도 로그인만으로 구매를 부여하지 않습니다.

백업 포함: 한자별 상태/정오답/복습, 학년 진행, 연속 학습일, 즐겨찾기, 졸업 확인.

백업 제외: 광고 횟수/이용권, 구매 권한, 앱 아이콘 선택/확인 상태, 온보딩 설정. 학년 아이콘 해금은 복원한 학년 완료 기록으로 다시 계산합니다. 앱 삭제 시 백업하지 못한 기록은 복원할 수 없습니다.

## 5. 저장과 권한

`kanji_progress_backups`는 auth.users의 UUID당 JSON snapshot 한 개를 저장합니다. RLS로 자신의 행만 조회합니다. authenticated/anon은 테이블에 직접 쓸 수 없고, `save_kanji_progress_backup` RPC만 업로드에 사용합니다.

RPC는 `auth.uid()`와 요청 시작 시의 계정 ID 일치를 확인하고, 사용자 단위 잠금 + 예상 revision 비교로 원자적으로 갱신합니다. 계정 전환 중 요청이나 오래된 기기의 덮어쓰기를 거부합니다. snapshot은 최대 2MB이고 앱에서도 스키마/알려진 한자 ID/상태/카운터를 검사합니다. 구매 권한을 이 사용자 편집 가능한 snapshot에서 읽지 않습니다.

## 6. 계정 삭제

`supabase/functions/delete-account/index.ts`를 프로젝트에 배포해야 앱의 **계정 및 클라우드 기록 삭제**가 작동합니다.

```bash
supabase functions deploy delete-account --project-ref YOUR_PROJECT_REF --no-verify-jwt
```

gateway JWT 검사를 끄는 대신 함수가 **모든 요청의 Bearer token을 Supabase Auth getUser로 직접 검증**합니다. 인증된 사용자 본인만 삭제하며 요청 body의 ID를 삭제 권한으로 신뢰하지 않습니다. Supabase 호스팅 함수에 제공되는 service-role key는 서버에서만 사용합니다. auth.users 삭제 시 FK cascade로 백업도 삭제합니다. Google 계정 자체 및 기기의 학습 기록은 유지합니다.

Google Play에 제출할 개인정보처리방침/데이터 보안 정보와 웹 계정 삭제 요청 URL도 실제 운영 주소로 준비해야 합니다. 이 저장소는 웹사이트를 자동 게시하지 않습니다.

## 7. 도메인

기존 `morak.app`을 그대로 사용해 `kanji.morak.app`, `support.morak.app` 또는 `morak.app/kanji`를 운영할 수 있습니다. 서브도메인마다 도메인을 새로 구매할 필요는 없습니다. DNS/사이트/HTTPS 설정은 필요합니다.

여러 서비스를 그룹 브랜드로 묶고 싶을 때만 그룹명 도메인을 새로 구매하고 `morak.<그룹도메인>`, `sukukanji.<그룹도메인>`으로 나누면 됩니다. 기존 도메인의 이름을 바꾸는 것이 아니라 새 도메인을 추가 구입하는 방식입니다. 앱 백업을 시작하는 데는 자체 도메인이 필요하지 않습니다.

## 출시 전 실제 연결 검증

이 환경에서는 프로젝트를 생성/배포하거나 실제 Google 계정으로 로그인하지 않았습니다. 실제 프로젝트에서 아래를 확인해야 합니다.

- Google 로그인 성공·취소·재실행 후 세션 복원, Android 콜드/웜 시작 callback
- 실제 SQLite 데이터로 백업 → 앱 재설치 → 같은 계정 로그인 → 복원
- 서로 다른 두 계정의 RLS 분리, stale revision RPC 오류, 로그아웃/계정 전환 중 요청
- 비행기 모드에서 학습 후 온라인 복귀 백업
- 계정 삭제 후 auth.users와 백업 제거, 앱의 로컬 학습 기록 유지
- 계정 삭제 요청 웹페이지와 개인정보처리방침 공개

참고: https://supabase.com/docs/guides/auth/social-login/auth-google · https://supabase.com/docs/reference/dart/auth-signinwithoauth · https://supabase.com/docs/guides/database/postgres/row-level-security
