# NationalGym 바디스캔 — 작업 인수인계 (Handoff)

> 새 채팅방에서 이 파일을 첨부하면 바로 이어서 작업 가능. 최종 업데이트: 2026-06-04, v1.20.3

---

## 1. 프로젝트 개요
- **무엇**: 헬스장(NationalGym) 트레이너용 **체형분석 웹앱**. 회원의 Before/After 자세 사진을 찍어 자세 각도를 자동 측정·비교하고 AI 분석·교정운동을 제공.
- **구조**: **단일 파일 `index.html`** (HTML+CSS+JS 전부 인라인, 약 7,000줄) + `poses/*.webp`(촬영 가이드 실루엣 10장) + `mockup.html`, `methodology.html`, `checklist-reduction.html`(회의용 보조 문서).
- **호스팅**: GitHub Pages. **저장소** `wellnessmode/nationalgym-analysis`.
- **라이브 URL**: https://wellnessmode.github.io/nationalgym-analysis/
- **기술스택**: 순수 JS, MediaPipe Pose(스켈레톤 감지, CDN), jsPDF + html2canvas(PDF), Cloudflare R2(클라우드 저장).

## 2. Git / 배포 규칙 (중요)
- **개발 브랜치**: `claude/continue-body-analysis-fixes-ajrle`
- **배포 흐름**: 작업 → feature 브랜치 커밋/푸시 → `main`에 `--ff-only` 머지 → main 푸시 → GitHub Pages 자동 빌드(1~2분).
- **푸시 방법**: 로컬 git 프록시(`origin`) 사용. 보통 `git push origin <branch>`로 됨. 막히면 PAT로 직접 푸시했었음:
  - PAT(만료됐을 수 있음): `github_pat_11B4SY5GQ0G...` — 만료 시 사용자에게 새 PAT 요청.
  - `git push https://x-access-token:$PAT@github.com/wellnessmode/nationalgym-analysis.git <branch>`
- **커밋 메시지 끝에** 항상: `https://claude.ai/code/session_015muSiEQMZJQqXGhh4Fw4hb`
- GitHub MCP 도구는 `wellnessmode/nationalgym-analysis`로만 제한됨.

## 3. 검증 워크플로 (반드시 커밋 전 실행)
사용자가 "대충 만든다"고 여러 번 지적 → **커밋 전 반드시 검증**할 것:
1. **JS 문법**: 4개 `<script>` 블록을 `new Function(body)`로 파싱 검사 (0 errors 확인).
2. **계측 수학**: `/tmp/sim.js` (합성 랜드마크 15케이스) — 전면/후면 기울기, 측면 두부전방, SLR, 외전 등.
3. **실루엣 렌더**: POSE_GUIDES를 node로 추출 → cairosvg로 PNG 래스터화 → 육안 확인. (jsdom, cairosvg, scipy, numpy, Pillow 설치돼 있음. `pip install` 가능)
4. **DOM/렌더**: jsdom으로 renderChangelog 등 실제 동작 확인.
- 검증 도구는 `/tmp`에서 실행 (cwd 주의 — 일부 명령 후 cwd가 리셋됨).

## 4. 버전 히스토리 핵심 (v1.15 → v1.20.3)
- **v1.15~1.16**: 트레이너 피드백 1차 — Before/After 좌우비교, 측정선, 스켈레톤 점편집(드래그), 항목 그룹핑, 검사 순서 정렬.
- **v1.17**: 측정값 직관화 — 어깨/골반/머리 기울기 "우↑/좌↑" 부호 표기, 픽셀→각도 변환, CVA/Q-angle/무릎비율 제거.
- **v1.17.1**: **전면 기울기 180° 버그 수정**(미러로 atan2 dx 음수 → `abs(dx)`), SLR 들린다리 자동선택, 측면 facing 방향 인식.
- **v1.18**: **종합점수 오염 수정** — `calcM`은 모든 자세에 모든 지표 계산하므로, `TEST_METRICS` 화이트리스트 + `aggregateRelevant()`로 검사별 관련 지표만 집계.
- **v1.19**: 엔터프라이즈 UX 개편 — 홈 2×2 그리드, 인체비례 SVG 실루엣 빌더, 성별(cGender)·키 입력으로 실루엣 보정, 카메라 박스 확대.
- **v1.19.4**: 어깨 외전=**후면**, 무릎 들기=**정면** 확정.
- **v1.20.0~1.20.1**: **실사 PNG 실루엣 적용** (`poses/*.webp`), 검은 반점 제거(내부 구멍 채우기), 강조 부위 골드 솔리드.
- **v1.20.2~1.20.3**: 홈 변경내역 항상 펼침(아코디언 제거), DOMContentLoaded 트리거 보강.

## 5. 핵심 측정 로직 (calcM, index.html 내)
- `calcM(lm,W,H)`: MediaPipe 33 랜드마크 → 자세 각도. **모든 지표를 자세 무관하게 계산**(주의: 누운 SLR도 spineAngle≈90° 나옴).
- **부호 규칙**: shoulderTilt/hipTilt = +우측높음/−좌측높음 (`abs(dx)`로 수평거리). headTilt/spineAngle = +우/−좌. headOffsetAngle = +전방(FHP)/−후방 (측면 facing 방향 `faceDir`로 보정). thoracicKyphosis = +어깨앞으로.
- **SLR**: `slrAngle` = 양쪽 허벅지(고관절→무릎) 중 더 가파른(들린) 다리 각도.
- **TEST_METRICS**(최상위 const): 검사ID→표시·채점할 지표 화이트리스트. `metricsForTest(tid)`, `aggregateRelevant(slot)`이 사용. **표(buildMetricsHTML)·종합점수·AI프롬프트·운동추천이 전부 이걸 공유**.
- 제거된 지표(코드에서 완전 삭제): cva, qAngleL/R, kneeAlign(전면), shoulderHDiff/hipHDiff, devEar/Shoulder/Hip/Knee(픽셀 플럼라인).

## 6. 촬영 가이드 실루엣 (poses/)
- **10개 webp**: ant, lat, post, shf(어깨외전 후면), sku(무릎들기 정면), ohs_b, ohs_l, trunk_l, trunk_b, slr. 총 ~280KB.
- **POSE_IMG 맵**(index.html): 13개 자세ID → `{b:파일베이스, m:좌우반전}`. 좌/우 쌍은 같은 이미지 `scaleX(-1)`.
  - sh_flex_l={b:shf,m:1}, sh_flex_r={b:shf}; sku={b:sku,m:1}, sku_r={b:sku}; slr_l={b:slr}, slr_r={b:slr,m:1}.
- `updateCamGuide(tid)`(2곳 정의, **나중 정의가 활성**): POSE_IMG 있으면 `<img id="camGuideImg">` 표시, 없으면 SVG `buildSilhouette()` 폴백.
- **실사 이미지 생성 파이프라인**(재생성 필요 시): 원본 AI PNG → 색상 키잉(greenness/gold) → `scipy.ndimage.binary_fill_holes`(작은 구멍만, 팔다리 갭 보존) → 평면 민트 재채색 + 골드 강조림 채우기 → 알파 트림/리사이즈 → webp q84. (이전 작업 디렉터리 `/tmp/sil_assets`, 출력 `/tmp/poses`).
- **남은 자산 작업**: 원본 업로드 zip은 `/root/.claude/uploads/...`에 있었음. 13자세 전부 커버됨(좌우 반전 포함). 더 좋은 실사 원하면 사용자가 새 PNG 제공 → 위 파이프라인으로 교체.

## 7. 검사 순서 (TESTS, 사용자 확정)
전면(1) → 좌측면(2) → 후면(3) → 어깨외전 좌(4)/우(5, **후면**) → 무릎들기 좌(6)/우(7, **정면**) → OHS 후면(8)/좌측면(9) → 트렁크 좌측면(10)/후면(11) → SLR 좌(12)/우(13, 가로촬영) → 수기검사(14~20).

## 8. 트레이너/회원 설정
- **담당 트레이너 명단**(cTrainer select): 정인재, 오경석, 이하은, 이상렬, 이희성.
- **회원정보 입력**: 이름(cName), 성별(cGender M/F), 키(cHeight), 트레이너, 이메일/전화. 성별·키는 SVG 실루엣 비례에 반영(`_silhouetteParams`).

## 9. 카메라 가이드 UI 동작
- 박스: 세로 자세 여백 상하 3.5%·좌우 3%. **SLR(가로 viewBox)은 여백 2%**(화면 최대).
- 안내문: 박스 안. 경고문은 **5초 후 자동 페이드아웃**(인라인 opacity 1→0, `#camWarning{transition:opacity 1s}`). ⚠️ 인라인 opacity가 CSS class를 이기므로 반드시 인라인으로 제어.
- 디바이스 수평계: 가로(SLR)는 gamma 기반, ±45° 클램프(−269° 버그 방지).

## 10. 현재 미해결 / 진행 중 이슈
1. **홈 변경내역 박스가 사용자 화면에 안 보임** (v1.20.3까지 대응했으나 사용자 "변화 없음"):
   - jsdom 검증으로는 renderChangelog 정상(41 entries, display block, 내용 노출).
   - 코드상 히어로 아래에 위치, 항상 펼침, DOMContentLoaded+load 다중 트리거, 진한 배경/테두리/min-height 200px 적용함.
   - **가장 유력한 원인: 사용자 브라우저 캐시** (버전 배너 v1.20.2는 보이는데 박스만 안 보임 = 부분 캐시 or 빌드 전 스크린샷). 사용자에게 강제 새로고침/시크릿탭/`?v=` 쿼리 안내함.
   - **다음 단계**: 새 스크린샷으로 실제 렌더 확인. 안 되면 변경내역을 features **아래**로 옮기거나, 별도 모달/페이지로 분리 고려. 또는 캐시 무효화 강화(meta no-cache는 이미 있음).
2. **PDF 다운로드**: html2canvas 로드 가드 + 캔버스 한계 적응형 스케일 적용했으나, 실기기 최종 확인 미완.
3. **MediaPipe 포즈 감지 한계**: SLR 누운 자세에서 들린 다리 관절 오인 가능 → 트레이너가 "점 편집"으로 수동 보정 필요(기능 있음).

## 11. 사용자 커뮤니케이션 톤
- 한국어. **간결하게**(사용자가 "압축" 요청). 변명 금지, 근본원인 규명 우선.
- 커밋 전 검증 결과(시뮬레이션/렌더)를 보여줄 것. 같은 버그 반복 수정에 민감함.

## 12. 빠른 시작 체크리스트 (새 세션에서)
```bash
cd /home/user/nationalgym-analysis
git status && git log --oneline -5
grep "const APP_VERSION=" index.html
# JS 문법 검사
node -e "const fs=require('fs');const h=fs.readFileSync('index.html','utf8');const re=/<script\b[^>]*>([\s\S]*?)<\/script>/gi;let m,i=0,e=0;while((m=re.exec(h))){i++;const b=m[1].trim();if(!b)continue;try{new Function(b)}catch(err){e++;console.log(err.message)}}console.log('JS errors:',e);"
```
배포: feature 커밋·푸시 → `git checkout main && git merge --ff-only <branch> && git push origin main` → feature로 복귀.
