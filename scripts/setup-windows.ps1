# =====================================================
# scripts/setup-windows.ps1
# 내셔널짐 PT 업무공유 PWA — Windows 환경 부트스트랩
#
# 실행 방법 (PowerShell, 관리자 권한 불필요):
#   cd C:\dev\nationalgym-tasks\scripts
#   powershell -ExecutionPolicy Bypass -File setup-windows.ps1
#
# 동작:
#   1. Node / Git / Flutter 설치 상태 확인
#   2. Firebase CLI 설치 (Node 필요)
#   3. scripts/ 의 npm 의존성 설치
#   4. .env 파일 자동 생성 (.env.example 복사)
#   5. (옵션) Flutter create로 Web 스캐폴드 생성 + 우리 web/ 복원
# =====================================================

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent

function Write-Step($msg)  { Write-Host "▶ $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "  △ $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " 내셔널짐 PT 업무공유 PWA — Windows 환경 부트스트랩" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# 1) Node 체크
Write-Step "Node.js 확인"
try {
    $nodeVersion = (& node --version) -replace '^v',''
    $major = [int](($nodeVersion -split '\.')[0])
    if ($major -lt 20) {
        Write-Fail "Node $nodeVersion (20 이상 필요). https://nodejs.org/ 에서 LTS 설치"
        exit 1
    }
    Write-Ok "Node $nodeVersion"
} catch {
    Write-Fail "Node 미설치. https://nodejs.org/ 에서 LTS 다운로드 후 설치"
    exit 1
}

# 2) Git 체크
Write-Step "Git 확인"
try {
    $gitVersion = & git --version
    Write-Ok $gitVersion
} catch {
    Write-Fail "Git 미설치. https://git-scm.com/download/win 에서 설치"
    exit 1
}

# 3) Flutter 체크
Write-Step "Flutter 확인"
$flutterInstalled = $false
try {
    $flutterFirstLine = (& flutter --version 2>&1 | Select-Object -First 1)
    Write-Ok $flutterFirstLine
    $flutterInstalled = $true
} catch {
    Write-Warn "Flutter 미설치"
    Write-Host "    설치 안내: https://docs.flutter.dev/get-started/install/windows"
    Write-Host "    이 프로젝트는 Web만 쓰므로 Xcode/Android Studio 불필요."
    Write-Host "    Chrome + Flutter SDK 만 있으면 됨."
}

# 4) Firebase CLI 설치
Write-Step "Firebase CLI 확인 / 설치"
try {
    $fbVersion = & firebase --version 2>$null
    Write-Ok "Firebase CLI $fbVersion"
} catch {
    Write-Host "  npm install -g firebase-tools 실행..."
    & npm install -g firebase-tools 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Firebase CLI 설치 완료"
    } else {
        Write-Fail "설치 실패. PowerShell을 관리자 권한으로 다시 실행"
    }
}

# 5) scripts/ npm 의존성 설치
Write-Step "scripts/ 의존성 설치 (pg 등)"
Push-Location $PSScriptRoot
& npm install --silent 2>&1 | Out-Host
Pop-Location
if ($LASTEXITCODE -eq 0) {
    Write-Ok "npm install 완료"
} else {
    Write-Fail "npm install 실패"
    exit 1
}

# 6) .env 파일 생성
Write-Step ".env 파일 확인"
$envFile = Join-Path $projectRoot ".env"
$envExample = Join-Path $projectRoot ".env.example"
if (Test-Path $envFile) {
    Write-Ok ".env 이미 존재 (변경 없음)"
} else {
    Copy-Item $envExample $envFile
    Write-Ok ".env 생성됨 — Supabase/Firebase 키 채워넣으세요"
}

# 7) Flutter create (옵션, 사용자 확인)
if ($flutterInstalled) {
    $libExists = Test-Path (Join-Path $projectRoot "lib\main.dart")
    if (-not $libExists) {
        Write-Step "Flutter Web 스캐폴드 생성 (lib/main.dart 등)"
        $confirm = Read-Host "  flutter create . --platforms=web 실행할까요? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            # 우리 web/ 백업
            $webBackup = Join-Path $env:TEMP "ng-web-backup"
            if (Test-Path $webBackup) { Remove-Item -Recurse -Force $webBackup }
            Copy-Item (Join-Path $projectRoot "web") $webBackup -Recurse

            Push-Location $projectRoot
            & flutter create . --platforms=web --project-name=nationalgym_tasks --org=local.nationalgym 2>&1 | Out-Host
            Pop-Location

            # 우리 web/ 복원 (Flutter 기본값 덮어쓰기)
            Copy-Item (Join-Path $webBackup "*") (Join-Path $projectRoot "web\") -Recurse -Force
            Remove-Item -Recurse -Force $webBackup
            Write-Ok "Flutter 스캐폴드 + 우리 PWA web/ 복원 완료"
        } else {
            Write-Warn "스킵. 나중에 직접 'flutter create . --platforms=web' 실행"
        }
    } else {
        Write-Ok "Flutter 스캐폴드 이미 존재"
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host " 셋업 완료" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:"
Write-Host "  1. .env 에 Supabase·Firebase 키 채우기 (메모장으로 .env 열기)"
Write-Host "  2. Supabase 마이그레이션:    cd scripts; node migrate.mjs"
Write-Host "  3. 마이그레이션 검증:        cd scripts; node verify.mjs"
Write-Host "  4. Supabase Auth 사용자 3명 수동 생성 (Dashboard)"
Write-Host "  5. iOS 푸시 검증:            cd test-push; firebase init hosting; firebase deploy"
Write-Host ""
