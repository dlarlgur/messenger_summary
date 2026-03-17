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
const { getChargersByZcode, buildGeoIndex } = require('./services/evApi');

const ALL_ZCODES = ['11','21','27','28','29','30','31','36','41','42','43','44','45','46','47','48','49'];

async function warmEvCache() {
  const { keyExists } = require('./middleware/cache');

  // geo 인덱스 이미 있으면 스킵 (서버 재시작 시 Redis 데이터 유지)
  const alreadyBuilt = await keyExists('ev:geo');
  if (alreadyBuilt) {
    console.log('[CACHE] geo 인덱스 이미 존재 → 프리로드 스킵');
    return;
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
const accessLog = fs.createWriteStream(path.join(logDir, 'access.log'), { flags: 'a' });
const debugLog = fs.createWriteStream(path.join(logDir, 'debug.log'), { flags: 'a' });

// console.log/warn/error → debug.log + stdout 동시 출력
['log', 'warn', 'error'].forEach(method => {
  const orig = console[method].bind(console);
  console[method] = (...args) => {
    orig(...args);
    const line = `[${new Date().toISOString()}] ${args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ')}\n`;
    debugLog.write(line);
  };
});

// ─── Middleware ───
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined', { stream: accessLog }));
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

  // 6시간마다 geo 인덱스 재구축 (TTL 만료 방지)
  setInterval(() => warmEvCache(), 6 * 60 * 60 * 1000);
});

module.exports = app;
