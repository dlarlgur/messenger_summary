const axios = require('axios');
const fs = require('fs');
const path = require('path');

const PRICE_FILE = path.join(__dirname, '../data/evPrices.json');
const CHARGEINFO_COMPANY_URL = 'https://chargeinfo.ksga.org/ws/organization/company/list';
const CHARGEINFO_TARIFF_URL  = 'https://chargeinfo.ksga.org/ws/tariff/charger/list';

// 메모리 캐시
let priceMap = {}; // bid → { fastNonMember, fastMember, slowNonMember, slowMember }

// ─── 파일에서 로드 ───
function loadFromFile() {
  try {
    if (fs.existsSync(PRICE_FILE)) {
      const raw = fs.readFileSync(PRICE_FILE, 'utf8');
      priceMap = JSON.parse(raw);
      console.log('[EV Price] 파일 로드 완료: ' + Object.keys(priceMap).length + '개 운영사');
    }
  } catch (e) {
    console.warn('[EV Price] 파일 로드 실패:', e.message);
  }
}

// ─── chargeinfo API에서 요금 가져와 파일 저장 ───
async function fetchAndStorePrices() {
  console.log('[EV Price] chargeinfo 요금 정보 업데이트 시작...');
  try {
    const [companyRes, tariffRes] = await Promise.all([
      axios.get(CHARGEINFO_COMPANY_URL, { params: { feeShowYn: 'Y' }, timeout: 10000 }),
      axios.get(CHARGEINFO_TARIFF_URL, { timeout: 10000 }),
    ]);

    const companies = (companyRes.data && companyRes.data.result) || [];
    const tariffs   = (tariffRes.data  && tariffRes.data.result)  || [];

    // bid → companyName 맵
    const companyNames = {};
    for (const c of companies) {
      companyNames[c.bid] = c.companyName;
    }

    // bid별 요금 집계
    // csKindType: '1'=완속, '2'=급속 / customerType: 'M'=회원, 'G'=비회원
    const newMap = {};
    for (const t of tariffs) {
      const bid = t.bid;
      const csKindType = t.csKindType;
      const customerType = t.customerType;
      const averageFee = t.averageFee;
      if (!bid || !averageFee) continue;
      if (!newMap[bid]) {
        newMap[bid] = {
          companyName: companyNames[bid] || bid,
          fastNonMember: null,
          fastMember:    null,
          slowNonMember: null,
          slowMember:    null,
          updatedAt: new Date().toISOString(),
        };
      }
      const isFast = csKindType === '2';
      const isMember = customerType === 'M';
      const key = isFast
        ? (isMember ? 'fastMember' : 'fastNonMember')
        : (isMember ? 'slowMember' : 'slowNonMember');

      // 이미 값 있으면 더 낮은 값 저장 (소비자에게 유리한 쪽 표시)
      if (newMap[bid][key] === null || averageFee < newMap[bid][key]) {
        newMap[bid][key] = averageFee;
      }
    }

    if (Object.keys(newMap).length === 0) {
      console.warn('[EV Price] 가져온 요금 데이터 없음, 업데이트 스킵');
      return;
    }

    priceMap = newMap;
    fs.writeFileSync(PRICE_FILE, JSON.stringify(priceMap, null, 2), 'utf8');
    console.log('[EV Price] 업데이트 완료: ' + Object.keys(priceMap).length + '개 운영사 저장');
  } catch (e) {
    console.error('[EV Price] 요금 업데이트 실패:', e.message);
    // 실패해도 기존 파일 데이터 유지
  }
}

/**
 * busiId와 충전기 목록으로 적합한 단가 반환
 * @param {string} busiId - 환경부 API busiId (= chargeinfo bid)
 * @param {Array}  chargers - 충전기 배열 [{chgerType}]
 * @returns {{ fast, slow, fastMember, slowMember }}
 */
function lookupPrice(busiId, chargers) {
  chargers = chargers || [];
  const empty = { fast: null, slow: null, fastMember: null, slowMember: null };
  if (!busiId) return empty;
  const p = priceMap[busiId] || STATIC_PRICES[busiId];
  if (!p) return empty;

  // 완속: 02, 08 / 급속: 나머지
  const SLOW_TYPES = { '02': true, '08': true };
  const hasFast = chargers.some(function(c) { return c.chgerType && !SLOW_TYPES[c.chgerType]; });
  const hasSlow = chargers.some(function(c) { return c.chgerType && SLOW_TYPES[c.chgerType]; });

  return {
    fast:       hasFast ? (p.fastNonMember !== null ? p.fastNonMember : p.fastMember) : null,
    slow:       hasSlow ? (p.slowNonMember !== null ? p.slowNonMember : p.slowMember) : null,
    fastMember: hasFast ? p.fastMember : null,
    slowMember: hasSlow ? p.slowMember : null,
  };
}

/**
 * busiId로 운영사 전체 요금 정보 반환
 */
function getPriceByBid(busiId) {
  return priceMap[busiId] || STATIC_PRICES[busiId] || null;
}

// ─── chargeinfo에 없는 운영사 하드코딩 요금 ───
const STATIC_PRICES = {
  PC: {                     // 아이파킹 (파킹클라우드)
    companyName: '아이파킹',
    fastNonMember: 450,
    fastMember:    345,
    slowNonMember: 400,
    slowMember:    285,
  },
};

// 서버 시작 시 파일 로드
loadFromFile();

module.exports = { fetchAndStorePrices, lookupPrice, getPriceByBid };
