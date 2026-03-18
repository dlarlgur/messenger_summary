require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');

const gasRoutes = require('./routes/gas');
const evRoutes = require('./routes/ev');
const priceRoutes = require('./routes/prices');
const searchRoutes = require('./routes/search');
const versionRoutes = require('./routes/version');
const teslaRoutes = require('./routes/tesla');
const alertRoutes = require('./routes/alerts');
const { getChargersByZcode, buildGeoIndex } = require('./services/evApi');
const { fetchAndStorePrices } = require('./services/evPriceService');
const { runMinuteBatch } = require('./services/alertService');
const { initAlertTables } = require('./db');

const ALL_ZCODES = ['11','21','27','28','29','30','31','36','41','42','43','44','45','46','47','48','49'];

async function warmEvCache(force = false) {
  const { keyExists, del } = require('./middleware/cache');

  // 서버 재시작 시: geo 인덱스 이미 있으면 스킵 (Redis 데이터 유지)
  if (!force) {
    const alreadyBuilt = await keyExists('ev:geo');
    if (alreadyBuilt) {
      console.log('[CACHE] geo 인덱스 이미 존재 → 프리로드 스킵');
      return;
    }
  } else {
    console.log('[CACHE] 정기 갱신: zcode 캐시 삭제 후 전체 재구축 시작...');
    // zcode 캐시 삭제 → 환경부 API에서 신선한 데이터 재조회
    for (const zcode of ALL_ZCODES) {
      await del(`ev:stations:zcode:${zcode}`);
    }
  }

  console.log('[CACHE] EV 충전소 전국 데이터 프리로드 시작...');
  const allChargers = [];
  for (const zcode of ALL_ZCODES) {
    try {
      const result = await getChargersByZcode(zcode);
      allChargers.push(...result);
      console.log(`[CACHE] zcode ${zcode} 완료 (${result.length}건, 누적 ${allChargers.length}건)`);
    } catch (e) {
      console.error(`[CACHE] zcode ${zcode} 실패:`, e.message);
    }
  }
  console.log(`[CACHE] 전국 EV 데이터 프리로드 완료 (총 ${allChargers.length}건)`);
  if (allChargers.length > 0) {
    await buildGeoIndex(allChargers);
  }
}

const app = express();
const PORT = process.env.PORT || 3000;

// ─── 로그 설정 ───
const logDir = process.env.NODE_ENV === 'production' ? '/logs' : './logs';
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });

const LOG_MAX_BYTES = 10 * 1024 * 1024; // 10MB

// KST 날짜 문자열 (YYYY-MM-DD)
function kstDateStr() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10);
}

// KST 타임스탬프 (YYYY-MM-DD HH:mm:ss.SSS)
function kstTimestamp() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const d = kst.toISOString();
  return `${d.slice(0, 10)} ${d.slice(11, 23)}`;
}

// 날짜/용량 기반 로그 라이터
// - 오늘: debug.log / debug_1.log (용량 초과 시)
// - 전날: debug.2026-03-17.log / debug.2026-03-17_1.log
function createRotatingWriter(prefix) {
  let currentDate = kstDateStr();
  let currentSize = 0;
  let stream = null;

  const mainPath  = () => path.join(logDir, `${prefix}.log`);
  const overPath  = (i) => path.join(logDir, `${prefix}_${i}.log`);
  const archPath  = (d)  => path.join(logDir, `${prefix}.${d}.log`);
  const archOver  = (d, i) => path.join(logDir, `${prefix}.${d}_${i}.log`);

  function openStream() {
    if (stream) { try { stream.end(); } catch (_) {} }
    const p = mainPath();
    currentSize = fs.existsSync(p) ? fs.statSync(p).size : 0;
    stream = fs.createWriteStream(p, { flags: 'a' });
  }

  function archiveDate(date) {
    // 오버플로우 파일 먼저 날짜 접미사로 이동
    let i = 1;
    while (fs.existsSync(overPath(i))) {
      try { fs.renameSync(overPath(i), archOver(date, i)); } catch (_) {}
      i++;
    }
    // 메인 파일 이동
    if (fs.existsSync(mainPath())) {
      try { fs.renameSync(mainPath(), archPath(date)); } catch (_) {}
    }
  }

  function checkRotate() {
    const today = kstDateStr();
    if (today !== currentDate) {
      // 자정 지남 → 전날 파일 날짜명으로 아카이브 후 새 파일 오픈
      if (stream) { try { stream.end(); stream = null; } catch (_) {} }
      archiveDate(currentDate);
      currentDate = today;
      openStream();
      return;
    }
    if (currentSize >= LOG_MAX_BYTES) {
      // 용량 초과 → debug.log → debug_N.log 로 이동, 새 debug.log 시작
      if (stream) { try { stream.end(); stream = null; } catch (_) {} }
      let i = 1;
      while (fs.existsSync(overPath(i))) i++;
      try { fs.renameSync(mainPath(), overPath(i)); } catch (_) {}
      openStream();
    }
  }

  openStream();

  return {
    write(line) {
      checkRotate();
      stream.write(line);
      currentSize += Buffer.byteLength(line);
    },
    get asStream() {
      const self = this;
      return { write: (s) => self.write(s) };
    },
  };
}

const accessWriter = createRotatingWriter('access');
const debugWriter = createRotatingWriter('debug');

// console.log/warn/error → debug 로그 + stdout 동시 출력
['log', 'warn', 'error'].forEach(method => {
  const orig = console[method].bind(console);
  console[method] = (...args) => {
    const line = `[${kstTimestamp()}] ${args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ')}\n`;
    orig(line.trimEnd());
    debugWriter.write(line);
  };
});

// ─── Middleware ───
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    // 앱(모바일)은 origin 없음, 서버 내부 호출도 허용
    if (!origin) return callback(null, true);
    // 웹 클라이언트가 필요하면 도메인 추가
    callback(new Error('CORS not allowed'));
  },
}));
app.use(express.json());
app.use(morgan('combined', { stream: accessWriter.asStream }));
app.use(morgan('dev'));

// Rate limiting
app.use(rateLimit({
  windowMs: 1 * 60 * 1000, // 1분
  max: 120, // 분당 120회
  message: { error: 'Too many requests, please try again later.' },
}));

// ─── Routes ───
app.use('/api/stations/gas', gasRoutes);
app.use('/api/stations/ev', evRoutes);
app.use('/api/prices', priceRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/version', versionRoutes);
app.use('/api/stations/tesla', teslaRoutes);
app.use('/api/alerts', alertRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`\n⛽🔋 충전도우미 API 서버 가동`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`   ENV: ${process.env.NODE_ENV || 'development'}`);
  console.log(`   OPINET KEY: ${process.env.OPINET_API_KEY ? '✅' : '❌ .env 설정 필요'}`);
  console.log(`   EV KEY: ${process.env.EV_API_KEY ? '✅' : '❌ .env 설정 필요'}`);
  console.log(`   NAVER MAP KEY: ${process.env.NAVER_MAP_CLIENT_ID ? '✅' : '⚠️ 검색기능 비활성'}\n`);

  // 서버 시작 후 백그라운드로 전국 EV 데이터 프리로드
  setTimeout(() => warmEvCache(), 3000);

  // 6시간마다 환경부 API에서 신선한 데이터로 전체 재구축
  setInterval(() => warmEvCache(true), 6 * 60 * 60 * 1000);

  // 운영사별 충전 단가 로드 (chargeinfo.ksga.org)
  setTimeout(() => fetchAndStorePrices(), 5000);
  // 24시간마다 단가 갱신
  setInterval(() => fetchAndStorePrices(), 24 * 60 * 60 * 1000);

  // DB 테이블 초기화
  initAlertTables().catch(e => {
    console.error('[DB] 테이블 초기화 실패:', e.message || e);
    if (e.stack) console.error(e.stack);
  });

  // 매 분 정각(00초)에 맞춰 알림 배치 실행
  function scheduleAlertBatch() {
    const msToNextMinute = 60000 - (Date.now() % 60000);
    setTimeout(() => {
      runMinuteBatch().catch(e => {
        console.error('[ALERT] batch error:', e.message || e);
        console.error(e.stack);
      });
      setInterval(() => runMinuteBatch().catch(e => {
        console.error('[ALERT] batch error:', e.message || e);
        console.error(e.stack);
      }), 60 * 1000);
    }, msToNextMinute);
    console.log(`[ALERT] 다음 배치까지 ${(msToNextMinute / 1000).toFixed(1)}초 대기`);
  }
  scheduleAlertBatch();
});

module.exports = app;
