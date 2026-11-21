#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// 재촬영 재현성 테스트 (repeat-test)
//
// 목적: "같은 사람을 다시 찍으면 값이 달라진다"를 감이 아니라 숫자로 본다.
//       같은 사람·같은 자세 사진(= 참값이 변하지 않음)을 서는 위치·거리·조명·
//       폰 기울기만 바꿔 N번 넣고, 앱의 실제 calcM()이 내는 지표의 표준편차와
//       범위를 잰다. 수정 전후에 같은 명령을 돌려 편차가 줄었는지 비교한다.
//
// 실행:  node tools/repeat-test/run.js
//        TIERS=lite,full,heavy N=30 IMGS=내사진.jpg node tools/repeat-test/run.js
// 필요:  playwright(크로미움). 포즈 모델·라이브러리·샘플 사진은 첫 실행 때
//        tools/repeat-test/.cache/ 로 내려받는다(깃에는 올리지 않음).
//
// 조건: B = 센서 노이즈만(같은 프레이밍)      C = 재촬영(위치·거리·조명)
//       D = C + 폰 기울기 ±2°                 F = 라이브 추적(VIDEO 모드) 프레임 간
// 방식: single = 1회 검출   tta8 = 같은 프레임을 이동·확대·좌우반전 8회 검출한 중앙값
// ─────────────────────────────────────────────────────────────────────────────
const http = require('http'), fs = require('fs'), path = require('path');
const { execSync } = require('child_process');
const ROOT = path.resolve(__dirname, '../..'), CACHE = path.join(__dirname, '.cache');
const APP = process.env.APP || 'motion-beta.html';
const TASKS_VER = '0.10.18';
const SAMPLE = 'https://storage.googleapis.com/mediapipe-assets/male_full_height_hands.jpg';
const MODEL = t => `https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_${t}/float16/latest/pose_landmarker_${t}.task`;
const TIERS = (process.env.TIERS || 'full').split(',');
const N = +(process.env.N || 30);

function ensureAssets() {
  fs.mkdirSync(CACHE, { recursive: true });
  const get = (url, file) => { if (!fs.existsSync(file) || fs.statSync(file).size < 1000) { console.error('↓', url); execSync(`curl -sSL --fail --max-time 300 -o "${file}" "${url}"`, { stdio: 'inherit' }); } };
  if (!fs.existsSync(path.join(CACHE, 'package/vision_bundle.mjs'))) {
    console.error('↓ @mediapipe/tasks-vision@' + TASKS_VER);
    execSync(`npm pack @mediapipe/tasks-vision@${TASKS_VER} --silent && tar xzf mediapipe-tasks-vision-${TASKS_VER}.tgz`, { cwd: CACHE, stdio: 'inherit' });
  }
  for (const t of TIERS) get(MODEL(t), path.join(CACHE, `pose_${t}.task`));
  get(SAMPLE, path.join(CACHE, 'sample.jpg'));
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };
function serve() {
  const extra = {}; // /img/<n> → 사용자가 준 사진 절대경로
  const srv = http.createServer((q, s) => {
    const u = decodeURIComponent(q.url.split('?')[0]);
    const f = u.startsWith('/cache/') ? path.join(CACHE, u.slice(7)) : (extra[u] || path.join(ROOT, u));
    fs.readFile(f, (e, b) => { if (e) { s.writeHead(404); return s.end(); } s.writeHead(200, { 'content-type': MIME[path.extname(f).toLowerCase()] || 'application/octet-stream' }); s.end(b); });
  });
  return { srv, extra };
}

// ── 브라우저 안에서 실행되는 본체 ──
async function inPage({ IMGS, TIERS, N }) {
  const vision = await import('/cache/package/vision_bundle.mjs');
  const fileset = await vision.FilesetResolver.forVisionTasks('/cache/package/wasm');
  const mk = (tier, mode) => vision.PoseLandmarker.createFromOptions(fileset, { baseOptions: { modelAssetPath: `/cache/pose_${tier}.task`, delegate: 'CPU' }, runningMode: mode, numPoses: 1, minPoseDetectionConfidence: 0.5, minPosePresenceConfidence: 0.5, minTrackingConfidence: 0.5 });
  let seed = 1; const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
  const gauss = () => { let u = 0, v = 0; while (!u) u = rnd(); while (!v) v = rnd(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); };
  const load = src => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = src; });
  const FW = 720, FH = 1280; // 세로 카메라 프레임
  function frame(img, p) { // 인물을 프레임에 배치: scale·tx·ty(위치/거리), rot(폰 기울기°), bright(조명), noise(센서)
    const c = document.createElement('canvas'); c.width = FW; c.height = FH; const x = c.getContext('2d'); x.fillStyle = '#d9d6d0'; x.fillRect(0, 0, FW, FH);
    const s = Math.min(FW / img.width, FH / img.height) * (p.scale || 1);
    x.save(); x.translate(FW / 2 + (p.tx || 0) * FW, FH / 2 + (p.ty || 0) * FH); x.rotate((p.rot || 0) * Math.PI / 180); x.filter = `brightness(${p.bright || 1})`;
    x.drawImage(img, -img.width * s / 2, -img.height * s / 2, img.width * s, img.height * s); x.restore();
    if (p.noise) { const d = x.getImageData(0, 0, FW, FH), a = d.data; for (let i = 0; i < a.length; i += 4) { const n = gauss() * p.noise; a[i] += n; a[i + 1] += n; a[i + 2] += n; } x.putImageData(d, 0, 0); }
    return c;
  }
  const SWAP = [[1, 4], [2, 5], [3, 6], [7, 8], [9, 10], [11, 12], [13, 14], [15, 16], [17, 18], [19, 20], [21, 22], [23, 24], [25, 26], [27, 28], [29, 30], [31, 32]];
  const VARS = [[1, 0, 0, 0], [1, 0, 0, 1], [0.94, 8, -6, 0], [0.94, -8, 6, 1], [1.06, -10, 4, 0], [1.06, 10, -4, 1], [1, 12, 10, 0], [1, -12, -10, 1]]; // [확대, dx, dy, 좌우반전]
  function detect(lmk, c, vars) { // 변형본마다 검출 → 원본 좌표로 역변환 → 관절별 중앙값
    const sets = [];
    for (const [s, dx, dy, fl] of vars) {
      let src = c;
      if (s !== 1 || dx || dy || fl) { src = document.createElement('canvas'); src.width = FW; src.height = FH; const x = src.getContext('2d'); x.fillStyle = '#d9d6d0'; x.fillRect(0, 0, FW, FH); x.translate(FW / 2 + dx, FH / 2 + dy); x.scale(fl ? -s : s, s); x.drawImage(c, -FW / 2, -FH / 2); }
      const r = lmk.detect(src); if (!r.landmarks || !r.landmarks[0]) continue;
      let l = r.landmarks[0].map(p => ({ x: (((p.x * FW - FW / 2 - dx) / (fl ? -s : s)) + FW / 2) / FW, y: (((p.y * FH - FH / 2 - dy) / s) + FH / 2) / FH, z: p.z, visibility: p.visibility }));
      if (fl) { l = l.slice(); for (const [a, b] of SWAP) { const t = l[a]; l[a] = l[b]; l[b] = t; } }
      sets.push(l);
    }
    if (!sets.length) return null;
    const med = a => { const s = a.slice().sort((p, q) => p - q), m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
    return sets[0].map((_, i) => ({ x: med(sets.map(s => s[i].x)), y: med(sets.map(s => s[i].y)), z: 0, visibility: med(sets.map(s => s[i].visibility)) }));
  }
  const ang3 = (l, a, b, c) => { const v1x = (l[a].x - l[b].x) * FW, v1y = (l[a].y - l[b].y) * FH, v2x = (l[c].x - l[b].x) * FW, v2y = (l[c].y - l[b].y) * FH; return Math.acos(Math.max(-1, Math.min(1, (v1x * v2x + v1y * v2y) / (Math.hypot(v1x, v1y) * Math.hypot(v2x, v2y))))) * 180 / Math.PI; };
  const KEYS = ['shoulderTilt', 'hipTilt', 'headTilt', 'spineAngle', 'potsi', 'shoulderAbductionL', 'shoulderAbductionR', 'kneeL', 'kneeR', 'elbowL', 'elbowR'];
  const metrics = lm => { if (!lm) return null; const m = calcM(_normLM(lm), FW, FH); m.kneeL = ang3(lm, 23, 25, 27); m.kneeR = ang3(lm, 24, 26, 28); m.elbowL = ang3(lm, 11, 13, 15); m.elbowR = ang3(lm, 12, 14, 16); const o = {}; for (const k of KEYS) if (typeof m[k] === 'number' && isFinite(m[k])) o[k] = m[k]; return o; };
  const stat = arr => { const a = arr.filter(v => typeof v === 'number'); if (a.length < 2) return null; const mean = a.reduce((s, v) => s + v, 0) / a.length; const sd = Math.sqrt(a.reduce((s, v) => s + (v - mean) ** 2, 0) / (a.length - 1)); return { n: a.length, mean: +mean.toFixed(2), sd: +sd.toFixed(2), range: +(Math.max(...a) - Math.min(...a)).toFixed(2) }; };
  const agg = rows => { const o = { detected: rows.filter(Boolean).length + '/' + rows.length }; for (const k of KEYS) { const s = stat(rows.map(r => r && r[k])); if (s) o[k] = s; } return o; };
  const reshoot = roll => () => ({ scale: 0.72 + rnd() * 0.26, tx: (rnd() - .5) * 0.10, ty: (rnd() - .5) * 0.06, bright: 0.8 + rnd() * 0.4, noise: 3, rot: roll ? (rnd() - .5) * 2 * roll : 0 });
  const CONDS = [['B_센서노이즈만', () => ({ noise: 3 })], ['C_재촬영(위치·거리·조명)', reshoot(0)], ['D_재촬영+폰기울기±2°', reshoot(2)]];
  const res = {};
  for (const name of IMGS) {
    const img = await load(name); res[name] = {};
    for (const tier of TIERS) {
      const R = res[name][tier] = {}; const lmk = await mk(tier, 'IMAGE');
      for (const [cond, gen] of CONDS) {
        seed = 4242; const single = [], tta8 = [];
        for (let i = 0; i < N; i++) { const c = frame(img, gen()); single.push(metrics(detect(lmk, c, VARS.slice(0, 1)))); tta8.push(metrics(detect(lmk, c, VARS))); }
        R[cond] = { single: agg(single), tta8: agg(tta8) };
      }
      lmk.close();
      const lmV = await mk(tier, 'VIDEO'); seed = 31337; const rows = []; let ts = 1000;
      for (let i = 0; i < 45; i++) { ts += 33; const r = lmV.detectForVideo(frame(img, { noise: 3 }), ts); rows.push(r.landmarks && r.landmarks[0] ? metrics(r.landmarks[0]) : null); }
      R['F_라이브추적_프레임간'] = { single: agg(rows.slice(15)) }; lmV.close();
    }
  }
  return res;
}

(async () => {
  ensureAssets();
  const { chromium } = require('playwright');
  const { srv, extra } = serve();
  await new Promise(r => srv.listen(0, '127.0.0.1', r));
  const base = 'http://127.0.0.1:' + srv.address().port;
  const IMGS = (process.env.IMGS ? process.env.IMGS.split(',') : []).map((p, i) => { const u = `/img/${i}${path.extname(p)}`; extra[u] = path.resolve(p); return u; });
  if (!IMGS.length) IMGS.push('/cache/sample.jpg');
  const br = await chromium.launch({ args: ['--no-sandbox'] });
  const pg = await br.newPage();
  pg.on('pageerror', e => console.error('PAGE ERROR', String(e).slice(0, 200)));
  await pg.route(u => !u.href.startsWith(base), r => r.abort()); // 외부 CDN 차단 — 로컬 자산만 사용
  await pg.addInitScript(() => { try { localStorage.setItem('ng_onb_v21', '1'); } catch (e) {} });
  await pg.goto(`${base}/${APP}`, { waitUntil: 'domcontentloaded' });
  await pg.waitForFunction(() => typeof calcM === 'function' && typeof _normLM === 'function');
  const out = await pg.evaluate(inPage, { IMGS, TIERS, N });
  await br.close(); srv.close();
  const SHOW = (process.env.SHOW || 'shoulderTilt,hipTilt,headTilt,spineAngle,shoulderAbductionR,kneeL,elbowR').split(',');
  for (const [img, tiers] of Object.entries(out)) for (const [tier, R] of Object.entries(tiers)) {
    console.log(`\n══ ${img} · 모델 ${tier} · N=${N} ══`);
    for (const [cond, methods] of Object.entries(R)) for (const [method, v] of Object.entries(methods)) {
      console.log(`${cond} · ${method}  (검출 ${v.detected})`);
      for (const k of SHOW) if (v[k]) console.log(`   ${k.padEnd(20)} 평균 ${String(v[k].mean).padStart(7)}°   표준편차 ${String(v[k].sd).padStart(5)}°   범위 ${String(v[k].range).padStart(5)}°`);
    }
  }
  if (process.env.OUT) fs.writeFileSync(process.env.OUT, JSON.stringify(out, null, 1));
})().catch(e => { console.error(e); process.exit(1); });
