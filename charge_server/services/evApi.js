const axios = require('axios');
const { parseStringPromise } = require('xml2js');
const { getCache, setCache, geoAdd, geoSearch, hSetBulk, hmGet, expire, keyExists, del, zRangeByScore, zRemRangeByScore, zRem } = require('../middleware/cache');
const { applyEvNavCoordOverride } = require('./evNavCoordOverrides');

// push_devices / EV 알림 구독과 동일 (routes/alerts.js, routes/ev.js)
const CHARGE_APP_ID = process.env.CHARGE_APP_ID || 'com.dksw.charge';

async function getEvAlarmSubscriberDeviceIds(stationId) {
  const { pool } = require('../db');
  const [rows] = await pool.execute(
    `SELECT device_id FROM ev_charger_alert_subscriptions
     WHERE app_id = ? AND station_id = ?`,
    [CHARGE_APP_ID, stationId]
  );
  return rows.map(r => r.device_id);
}

// Lazy load firebase-admin (같은 인스턴스, alertService와 공유)
let _admin = null;
function _getAdmin() {
  if (_admin) return _admin;
  try {
    const admin = require('firebase-admin');
    const path = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!path) return null;
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(require(path)) });
    }
    _admin = admin;
    return _admin;
  } catch { return null; }
}

const BASE_URL = 'http://apis.data.go.kr/B552584/EvCharger';
const API_KEY = process.env.EV_API_KEY;
const EV_CACHE_TTL = 25 * 60 * 60; // zcode 풀 데이터 캐시: 25시간 (재구축 실패 시 이전 성공 캐시 재사용)
const GEO_TTL      = 24 * 60 * 60; // geo 인덱스: 24시간

const ALL_ZCODES = ['11','21','27','28','29','30','31','36','41','42','43','44','45','46','47','48','49'];

const GEO_KEY  = 'ev:geo';
const DATA_KEY = 'ev:stations:data'; // hash: statId → JSON (위치 + 최신 상태 포함)

let _isWarmingUp = false;
function setWarmingUp(val) { _isWarmingUp = val; }

// ─── 환경부 EV API 호출 ───
async function callEvApi(endpoint, params = {}) {
  const callParams = { ...params };
  delete callParams.serviceKey;
  console.log(`[EV API] →  ${endpoint}`, callParams);
  const t0 = Date.now();
  try {
    const res = await axios.get(`${BASE_URL}/${endpoint}`, {
      params: { serviceKey: API_KEY, numOfRows: 9999, ...params },
      timeout: 45000,
      responseType: 'text',
    });

    let data = res.data;
    if (typeof data === 'string' && data.includes('<?xml')) {
      const parsed = await parseStringPromise(data, { explicitArray: false, ignoreAttrs: true });
      const body = parsed && parsed.response && parsed.response.body ? parsed.response.body : parsed;
      console.log(`[EV API] ←  ${endpoint} XML (${Date.now() - t0}ms)`);
      return body;
    }
    if (typeof data === 'string') data = JSON.parse(data);
    let items = null;
    if (data && data.items) {
      if (Array.isArray(data.items) && data.items.length > 0 && data.items[0] && data.items[0].item) {
        items = data.items[0].item;
      } else if (data.items.item) {
        items = data.items.item;
      }
    }
    const count = Array.isArray(items) ? items.length : (items ? 1 : 0);
    console.log(`[EV API] ←  ${endpoint} JSON ${count}건 (${Date.now() - t0}ms)`);
    return data;
  } catch (err) {
    console.error(`[EV API] ✗  ${endpoint} (${Date.now() - t0}ms):`, err.message);
    throw err;
  }
}

function extractItems(body) {
  let raw = null;
  if (body && body.items) {
    if (Array.isArray(body.items) && body.items.length > 0 && body.items[0] && body.items[0].item) {
      raw = body.items[0].item;
    } else if (body.items.item) {
      raw = body.items.item;
    }
  }
  if (!raw) return [];
  return Array.isArray(raw) ? raw : [raw];
}

// ─── 시도 전체 조회 (geo 인덱스 구축용) ───
const inflightZcode = new Map();

async function getChargersByZcode(zcode) {
  const cacheKey = `ev:stations:zcode:${zcode}`;
  const cached = await getCache(cacheKey);
  if (cached) {
    console.log(`[EV Cache] HIT zcode=${zcode} (${cached.length}건)`);
    return cached;
  }

  if (inflightZcode.has(zcode)) {
    console.log(`[EV Cache] WAIT inflight zcode=${zcode}`);
    return inflightZcode.get(zcode);
  }

  const promise = (async () => {
    const allItems = [];
    let pageNo = 1;
    let totalPages = null;
    while (true) {
      try {
        const data = await callEvApi('getChargerInfo', { zcode, pageNo });
        const items = extractItems(data);
        allItems.push(...items);
        console.log(`[EV Cache] zcode=${zcode} page=${pageNo} ${items.length}건 (누적 ${allItems.length}건)`);

        // 첫 페이지 응답의 totalCount/numOfRows 기반으로 총 페이지 수 계산
        if (totalPages == null && data && data.header) {
          const hArr = Array.isArray(data.header) ? data.header : [data.header];
          const h = hArr[0] || {};
          const totalCount = parseInt(h.totalCount || '0', 10);
          const numOfRows = parseInt(h.numOfRows || '9999', 10) || 9999;
          if (totalCount > 0 && numOfRows > 0) {
            totalPages = Math.ceil(totalCount / numOfRows);
          }
        }

        // 더 가져올 페이지 없으면 종료
        if (items.length === 0) break;
        if (totalPages != null && pageNo >= totalPages) break;

        pageNo++;
        await new Promise(r => setTimeout(r, 300));
      } catch (e) {
        // 페이지 실패 시 지금까지 수집한 부분 데이터로 진행 (전체 폐기 방지)
        console.warn(`[EV Cache] zcode=${zcode} page=${pageNo} 실패 (누적 ${allItems.length}건으로 저장):`, e.message);
        break;
      }
    }
    if (allItems.length > 0) {
      await setCache(cacheKey, allItems, EV_CACHE_TTL);
      console.log(`[EV Cache] SET zcode=${zcode} 전체 ${allItems.length}건`);
    }
    return allItems;
  })();

  inflightZcode.set(zcode, promise);
  try {
    return await promise;
  } finally {
    inflightZcode.delete(zcode);
  }
}


// ─── Geo 인덱스 구축 ───
// incremental 업데이트: 기존 ev:stations:data 보존하면서 새 데이터 덮어씀
// atomic rename 방식 제거 → 일부 zcode 실패해도 기존 데이터 유지
async function buildGeoIndex(allChargers) {
  console.log(`[EV Geo] 인덱스 구축 시작 (충전기 ${allChargers.length}건)`);

  const stationMap = new Map();
  for (const c of allChargers) {
    const lat = parseFloat(c.lat);
    const lng = parseFloat(c.lng);
    if (!c.statId || !lat || !lng || isNaN(lat) || isNaN(lng)) continue;

    if (!stationMap.has(c.statId)) {
      stationMap.set(c.statId, {
        statId: c.statId,
        statNm: c.statNm,
        addr: c.addr,
        lat, lng,
        busiId: c.busiId,
        busiNm: c.busiNm,
        busiCall: c.busiCall || '',
        kind: c.kind,
        kindDetail: c.kindDetail,
        useTime: c.useTime || '24시간',
        parkingFree: c.parkingFree === 'Y',
        limitYn: c.limitYn || 'N',
        limitDetail: c.limitDetail || '',
        note: c.note || '',
        chargers: [],
      });
    }
    stationMap.get(c.statId).chargers.push({
      chgerId: c.chgerId,
      chgerType: c.chgerType,
      output: parseInt(c.output || '7'),
      stat: parseInt(c.stat || '9'),
      statUpdDt: c.statUpdDt || '',
      nowTsdt: c.nowTsdt || '',
      lastTsdt: c.lastTsdt || '',
      lastTedt: c.lastTedt || '',
      unitPrice: c.unitPrice ? parseInt(c.unitPrice) : null,
    });
  }

  const stations = [...stationMap.values()];
  if (stations.length === 0) {
    console.warn('[EV Geo] 구축할 데이터 없음');
    return 0;
  }

  // GEOADD는 원래 incremental (기존 멤버 보존 + 새 멤버 추가/업데이트)
  const geoMembers = stations.map(s => ({ longitude: s.lng, latitude: s.lat, member: s.statId }));
  await geoAdd(GEO_KEY, geoMembers);
  await expire(GEO_KEY, GEO_TTL);

  // HSET도 incremental (기존 필드 보존 + 새 필드 추가/업데이트)
  // → 실패한 zcode 데이터는 기존 값 유지, 성공한 zcode만 덮어씀
  const dataFields = {};
  for (const s of stations) dataFields[s.statId] = JSON.stringify(s);
  await hSetBulk(DATA_KEY, dataFields);
  await expire(DATA_KEY, GEO_TTL);

  console.log(`[EV Geo] 인덱스 구축 완료: ${stations.length}개 충전소`);
  return stations.length;
}

// ─── 시도 경계 ───
const REGIONS = [
  { zcode: '11', latMin: 37.41, latMax: 37.70, lngMin: 126.76, lngMax: 127.18 },
  { zcode: '28', latMin: 37.28, latMax: 37.56, lngMin: 126.35, lngMax: 126.78 },
  { zcode: '41', latMin: 36.90, latMax: 38.30, lngMin: 126.60, lngMax: 127.90 },
  { zcode: '21', latMin: 35.05, latMax: 35.32, lngMin: 128.88, lngMax: 129.32 },
  { zcode: '27', latMin: 35.78, latMax: 36.04, lngMin: 128.42, lngMax: 128.76 },
  { zcode: '31', latMin: 35.44, latMax: 35.62, lngMin: 129.27, lngMax: 129.51 },
  { zcode: '30', latMin: 36.18, latMax: 36.52, lngMin: 127.28, lngMax: 127.60 },
  { zcode: '29', latMin: 35.27, latMax: 35.44, lngMin: 126.78, lngMax: 127.02 },
  { zcode: '36', latMin: 36.46, latMax: 36.58, lngMin: 127.26, lngMax: 127.40 },
  { zcode: '43', latMin: 36.40, latMax: 37.20, lngMin: 127.40, lngMax: 128.60 },
  { zcode: '44', latMin: 36.00, latMax: 37.10, lngMin: 126.30, lngMax: 127.30 },
  { zcode: '47', latMin: 35.60, latMax: 36.80, lngMin: 127.40, lngMax: 129.30 },
  { zcode: '48', latMin: 34.60, latMax: 35.60, lngMin: 127.40, lngMax: 129.00 },
  { zcode: '45', latMin: 35.00, latMax: 35.90, lngMin: 126.40, lngMax: 127.60 },
  { zcode: '46', latMin: 34.00, latMax: 35.10, lngMin: 126.10, lngMax: 127.60 },
  { zcode: '42', latMin: 37.10, latMax: 38.60, lngMin: 127.00, lngMax: 129.40 },
  { zcode: '49', latMin: 33.10, latMax: 33.60, lngMin: 126.10, lngMax: 126.99 },
];

// ─── 반경 내 충전소 검색 ───
async function getStationsAround({ lat, lng, radius = 3000 }) {
  console.log(`[EV Around] 요청: lat=${lat} lng=${lng} radius=${radius}`);
  const t0 = Date.now();

  // 1순위: Redis GEOSEARCH → ev:stations:data에서 바로 읽음 (배경 갱신으로 상태 최신 유지)
  const nearbyIds = await geoSearch(GEO_KEY, lng, lat, radius);
  if (nearbyIds !== null) {
    if (nearbyIds.length === 0) {
      const indexed = await keyExists(GEO_KEY);
      if (!indexed) {
        console.warn('[EV Around] geo index 미구축 → zcode fallback');
      } else {
        console.log(`[EV Around] GEOSEARCH 결과 없음 (${Date.now() - t0}ms)`);
        return [];
      }
    } else {
      const dataStrings = await hmGet(DATA_KEY, nearbyIds);
      const stations = [];
      for (let i = 0; i < nearbyIds.length; i++) {
        if (!dataStrings[i]) continue;
        const s0 = JSON.parse(dataStrings[i]);
        const s = applyEvNavCoordOverride(s0);
        const dist = haversineDistance(lat, lng, parseFloat(s.lat), parseFloat(s.lng));
        s.availableCount = s.chargers.filter(c => c.stat === 2).length;
        s.chargingCount  = s.chargers.filter(c => c.stat === 3).length;
        stations.push({ ...s, distance: Math.round(dist) });
      }
      stations.sort((a, b) => a.distance - b.distance);
      console.log(`[EV Around] GEOSEARCH ${stations.length}건 (${Date.now() - t0}ms)`);
      return stations;
    }
  }

  // 2순위: zcode fallback (warmEvCache 실행 중엔 스킵)
  if (_isWarmingUp) {
    console.log('[EV Around] warmEvCache 진행 중 → fallback 스킵, 빈 배열 반환');
    return [];
  }
  console.warn('[EV Around] geo index 없음 → zcode fallback');
  const latDelta = radius / 111000;
  const lngDelta = radius / (111000 * Math.cos(lat * Math.PI / 180));
  const fallbackZcodes = REGIONS
    .filter(r =>
      lat + latDelta >= r.latMin && lat - latDelta <= r.latMax &&
      lng + lngDelta >= r.lngMin && lng - lngDelta <= r.lngMax
    )
    .map(r => r.zcode);

  if (fallbackZcodes.length === 0) return [];

  const results = await Promise.all(fallbackZcodes.map(z => getChargersByZcode(z)));
  const seen = new Set();
  const all = [];
  for (const list of results) {
    for (const s of list) {
      const key = `${s.statId}_${s.chgerId}`;
      if (!seen.has(key)) { seen.add(key); all.push(s); }
    }
  }
  const filtered = filterByRadius(all, lat, lng, radius);
  console.log(`[EV Around] fallback ${filtered.length}건 (${Date.now() - t0}ms)`);
  return filtered;
}

function filterByRadius(stations, lat, lng, radius) {
  return stations
    .filter(s => s.lat && s.lng)
    .map(s => {
      const dist = haversineDistance(lat, lng, parseFloat(s.lat), parseFloat(s.lng));
      return { ...s, distance: Math.round(dist) };
    })
    .filter(s => s.distance <= radius)
    .sort((a, b) => a.distance - b.distance);
}

// ─── 충전소 상세 ───
async function getStationDetail(statId) {
  const staticKey = `ev:station:static:${statId}`;
  let staticData = await getCache(staticKey);

  if (!staticData) {
    // 1순위: ev:stations:data 해시 (배경 갱신으로 항상 최신 유지) → 외부 API 호출 없이 즉시 반환
    const [dataStr] = await hmGet(DATA_KEY, [statId]);
    if (dataStr) {
      const d = JSON.parse(dataStr);
      staticData = {
        statId: d.statId,
        name: d.statNm,
        address: d.addr,
        lat: d.lat,
        lng: d.lng,
        busiId: d.busiId,
        operator: d.busiNm,
        phone: d.busiCall || null,
        useTime: d.useTime || '24시간',
        parkingFree: d.parkingFree,
        limitYn: d.limitYn || 'N',
        limitDetail: d.limitDetail || '',
        note: d.note || '',
        kind: d.kind,
        kindDetail: d.kindDetail,
        chargers: d.chargers.map(c => ({
          chgerId: c.chgerId,
          chgerType: c.chgerType,
          output: c.output,
          unitPrice: c.unitPrice || null,
        })),
      };
      const unitPriceCharger = staticData.chargers.find(c => c.unitPrice);
      staticData.unitPrice = unitPriceCharger ? unitPriceCharger.unitPrice : null;
      await setCache(staticKey, staticData, GEO_TTL);
    } else {
      // 2순위: 환경부 외부 API (DATA_KEY에 없는 경우만 — 신규 충전소 등 극히 드묾)
      const data = await callEvApi('getChargerInfo', { statId });
      const infoList = extractItems(data);
      if (infoList.length === 0) return null;

      const info = infoList[0];
      staticData = {
        statId: info.statId,
        name: info.statNm,
        address: info.addr,
        lat: parseFloat(info.lat),
        lng: parseFloat(info.lng),
        busiId: info.busiId,
        operator: info.busiNm,
        phone: info.busiCall,
        useTime: info.useTime || '24시간',
        parkingFree: info.parkingFree === 'Y',
        limitYn: info.limitYn || 'N',
        limitDetail: info.limitDetail || '',
        note: info.note || '',
        kind: info.kind,
        kindDetail: info.kindDetail,
        chargers: infoList.map(s => ({
          chgerId: s.chgerId,
          chgerType: s.chgerType,
          output: parseInt(s.output || '7'),
          unitPrice: s.unitPrice ? parseInt(s.unitPrice) : null,
        })),
      };
      const unitPriceCharger = staticData.chargers.find(c => c.unitPrice);
      staticData.unitPrice = unitPriceCharger ? unitPriceCharger.unitPrice : null;
      await setCache(staticKey, staticData, GEO_TTL);
    }
  }

  // 실시간 상태: ev:stations:data에서 최신 상태 병합
  // (staticData가 이미 DATA_KEY 기반이면 재조회하지 않고 바로 병합 — 한 번만 조회)
  const [liveStr] = await hmGet(DATA_KEY, [statId]);
  if (liveStr) {
    const liveStation = JSON.parse(liveStr);
    const chargerMap = new Map(liveStation.chargers.map(c => [c.chgerId, c]));
    for (const c of staticData.chargers) {
      const live = chargerMap.get(c.chgerId);
      c.stat      = live?.stat      ?? 9;
      c.statUpdDt = live?.statUpdDt ?? '';
      c.nowTsdt   = live?.nowTsdt   ?? '';
      c.lastTsdt  = live?.lastTsdt  ?? '';
      c.lastTedt  = live?.lastTedt  ?? '';
    }
  } else {
    for (const c of staticData.chargers) {
      c.stat = 9;
      c.statUpdDt = '';
    }
  }

  // 충전기 중 가장 최근 statUpdDt (YYYYMMDDHHMMSS 문자열 비교)
  const lastStatusUpdate = staticData.chargers
    .map(c => c.statUpdDt)
    .filter(Boolean)
    .sort()
    ;

  const lastStatusUpdateValue = lastStatusUpdate.length ? lastStatusUpdate[lastStatusUpdate.length - 1] : null;

  return applyEvNavCoordOverride({
    ...staticData,
    totalCount:       staticData.chargers.length,
    availableCount:   staticData.chargers.filter(c => c.stat === 2).length,
    chargingCount:    staticData.chargers.filter(c => c.stat === 3).length,
    lastStatusUpdate: lastStatusUpdateValue, // 예: "20260319091238"
  });
}

// ─── Haversine 거리 계산 (미터) ───
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg) { return deg * Math.PI / 180; }

// ─── 전체 zcode 상태 배경 갱신 (3분 배치) ───
// period=10: 최근 10분 내 상태 변경된 충전기만 반환 → ev:stations:data에 영구 반영
// 순차 처리 + 500ms 간격 → 429 방지
// 캐시 삭제 없이 덮어씀 → 갱신 중에도 유저는 기존 데이터 사용 가능
async function refreshAllStatusCaches() {
  console.log('[EV Status] 배경 상태 갱신 시작...');
  let totalUpdated = 0;

  for (const zcode of ALL_ZCODES) {
    try {
      const allItems = [];
      let pageNo = 1;

      while (true) {
        const data = await callEvApi('getChargerStatus', { zcode, period: 10, pageNo });
        const items = extractItems(data);
        allItems.push(...items);
        if (items.length < 9999) break;
        pageNo++;
        await new Promise(r => setTimeout(r, 200));
      }

      if (allItems.length === 0) {
        console.log(`[EV Status] 배경갱신 zcode=${zcode} 변경 없음`);
      } else {
        // statId별로 그룹핑
        const byStation = new Map();
        for (const item of allItems) {
          if (!byStation.has(item.statId)) byStation.set(item.statId, []);
          byStation.get(item.statId).push(item);
        }

        // ev:stations:data에서 해당 충전소 읽어서 상태 업데이트 후 다시 씀
        const statIds = [...byStation.keys()];
        const dataStrings = await hmGet(DATA_KEY, statIds);
        const updates = {};
        // 알림: 충전가능(stat=2) 개수가 바뀐 충전소만 (기존은 avail 0→양수만 알림이라
        // 1→2자리, 2→3자리, 자리 줄어듦 등 대부분의 변화를 놓침)
        const alarmCandidates = []; // { statId, stationName, prevAvail, newAvail }

        for (let i = 0; i < statIds.length; i++) {
          if (!dataStrings[i]) continue;
          const station = JSON.parse(dataStrings[i]);
          const prevAvail = station.chargers.filter(c => c.stat === 2).length;
          for (const upd of byStation.get(statIds[i])) {
            const charger = station.chargers.find(c => c.chgerId === upd.chgerId);
            if (charger) {
              const prevStat = charger.stat;
              charger.stat      = parseInt(upd.stat || '9');
              charger.statUpdDt = upd.statUpdDt || '';
              charger.nowTsdt   = (upd.nowTsdt !== undefined && upd.nowTsdt !== null) ? upd.nowTsdt : charger.nowTsdt;
              charger.lastTsdt  = (upd.lastTsdt !== undefined && upd.lastTsdt !== null) ? upd.lastTsdt : charger.lastTsdt;
              charger.lastTedt  = (upd.lastTedt !== undefined && upd.lastTedt !== null) ? upd.lastTedt : charger.lastTedt;
              // stat=2(충전가능): 충전 방금 끝난 것 → statUpdDt = 마지막 충전 종료 시각
              if (charger.stat === 2 && upd.statUpdDt && upd.statUpdDt > (charger.lastTedt || '')) {
                charger.lastTedt = upd.statUpdDt;
              }
              // stat=3(충전중)으로 바뀐 경우: nowTsdt 없으면 statUpdDt = 충전 시작 시각
              if (charger.stat === 3 && prevStat !== 3 && upd.statUpdDt && !charger.nowTsdt) {
                charger.nowTsdt = upd.statUpdDt;
              }
            }
          }
          const newAvail = station.chargers.filter(c => c.stat === 2).length;
          if (prevAvail !== newAvail) {
            alarmCandidates.push({
              statId: statIds[i],
              stationName: station.statNm || statIds[i],
              prevAvail,
              newAvail,
              totalCount: station.chargers.length,
            });
          }
          updates[statIds[i]] = JSON.stringify(station);
        }

        if (Object.keys(updates).length > 0) {
          await hSetBulk(DATA_KEY, updates);
        }

        // FCM 알림 발송 (알림 구독자 있는 충전소만)
        for (const { statId, stationName, prevAvail, newAvail, totalCount } of alarmCandidates) {
          try {
            const deviceIds = await getEvAlarmSubscriberDeviceIds(statId);
            if (!deviceIds || deviceIds.length === 0) continue;
            // FCM 토큰 조회 (push_devices 테이블 — app_id 없이 조회하면 다른 앱/구버전 행과 섞일 수 있음)
            const { pool } = require('../db');
            const placeholders = deviceIds.map(() => '?').join(',');
            const [rows] = await pool.execute(
              `SELECT fcm_token FROM push_devices
               WHERE app_id = ? AND device_id IN (${placeholders})
                 AND fcm_token IS NOT NULL AND fcm_token <> ''`,
              [CHARGE_APP_ID, ...deviceIds]
            );
            const tokens = [...new Set(rows.map(r => r.fcm_token).filter(Boolean))];
            if (tokens.length === 0) {
              console.warn(
                `[EV ALARM] 스킵(토큰 없음): ${stationName} (${statId}) avail ${prevAvail}→${newAvail}, 구독 기기 ${deviceIds.length}대 / push_devices에 유효 FCM 0개`
              );
              continue;
            }
            const fb = _getAdmin();
            if (!fb) {
              console.warn(`[EV ALARM] 스킵(Firebase 미설정): ${stationName} (${statId}) avail ${prevAvail}→${newAvail}`);
              continue;
            }
            const title = `⚡ ${stationName}`;
            const totalChargers = totalCount;
            let changeText;
            let statusText;
            const diff = Math.abs(newAvail - prevAvail);
            if (newAvail > prevAvail) {
              if (prevAvail === 0) {
                changeText = diff === 1 ? '충전 자리가 생겼어요!' : `${diff}자리가 생겼어요!`;
              } else {
                changeText = `${diff}자리 늘었어요`;
              }
            } else {
              changeText = `${diff}자리 줄었어요`;
            }
            if (newAvail === 0) {
              statusText = '남은 자리가 없어요';
            } else if (totalChargers > 0 && newAvail === totalChargers) {
              statusText = `${newAvail}자리 모두 여유 있어요`;
            } else {
              statusText = `현재 ${newAvail}자리 남았어요`;
            }
            const body = `${changeText} · ${statusText}`;
            await fb.messaging().sendEachForMulticast({
              tokens,
              data: {
                type: 'ev_alarm',
                stationId: statId,
                stationName,
                title,
                body,
                prevAvail: String(prevAvail),
                newAvail: String(newAvail),
              },
              android: { priority: 'high' },
            });
            console.log(`[EV ALARM] 발송: ${stationName} avail ${prevAvail}→${newAvail} → ${tokens.length}명`);
          } catch (e) {
            console.error(`[EV ALARM] 발송 실패 ${statId}:`, e.message);
          }
        }

        // Watch 세션 체크: 자리 악화 시 해당 device에 별도 푸시
        await _checkWatchSessions(alarmCandidates);

        totalUpdated += allItems.length;
        console.log(`[EV Status] 배경갱신 zcode=${zcode} ${allItems.length}건 → ${Object.keys(updates).length}개 충전소 업데이트`);
      }
    } catch (e) {
      console.error(`[EV Status] 배경 갱신 실패 zcode=${zcode}:`, e.message);
    }

    await new Promise(r => setTimeout(r, 500)); // zcode 간 0.5초 간격
  }

  console.log(`[EV Status] 배경 상태 갱신 완료 (총 ${totalUpdated}건 변경 반영)`);
}

/**
 * 폴링 후 watch 세션 체크 — 자리 감소 시 해당 device에 FCM 푸시
 * alarmCandidates: [{ statId, stationName, prevAvail, newAvail, totalCount }]
 */
async function _checkWatchSessions(alarmCandidates) {
  if (!alarmCandidates || alarmCandidates.length === 0) return;

  const worsened = alarmCandidates.filter(c => c.newAvail < c.prevAvail);
  if (worsened.length === 0) return;

  const now = Date.now();
  const { pool } = require('../db');

  for (const { statId, stationName, prevAvail, newAvail } of worsened) {
    try {
      // scan 제거 → 역방향 인덱스로 O(1) 조회 (score >= now = 만료되지 않은 것만)
      const deviceIds = await zRangeByScore(`ev:watch:station:${statId}`, now, '+inf');
      // 만료 항목 정리
      await zRemRangeByScore(`ev:watch:station:${statId}`, 0, now - 1);
      if (!deviceIds || deviceIds.length === 0) continue;

      for (const deviceId of deviceIds) {
        const key = `ev:watch:${deviceId}:${statId}`;
        const session = await getCache(key);
        if (!session) {
          // 세션 만료 — 인덱스 정리
          await zRem(`ev:watch:station:${statId}`, deviceId);
          await zRem(`ev:watch:device:${deviceId}`, statId);
          continue;
        }

        const remainSec = Math.floor((new Date(session.expiresAt) - now) / 1000);
        if (remainSec <= 0) {
          await del(key);
          await zRem(`ev:watch:station:${statId}`, deviceId);
          await zRem(`ev:watch:device:${deviceId}`, statId);
          continue;
        }

        // prevAvail 갱신 (중복 알림 방지)
        await setCache(key, { ...session, prevAvail: newAvail }, remainSec);

        // FCM 토큰 조회
        const [rows] = await pool.execute(
          `SELECT fcm_token FROM push_devices
           WHERE app_id = ? AND device_id = ? AND fcm_token IS NOT NULL AND fcm_token <> ''`,
          [CHARGE_APP_ID, deviceId]
        );
        if (!rows.length) continue;
        const token = rows[0].fcm_token;

        const fb = _getAdmin();
        if (!fb) continue;

        const body = newAvail === 0
          ? '자리가 꽉 찼어요! 다른 충전소를 확인하세요'
          : `자리가 ${prevAvail}개 → ${newAvail}개로 줄었어요`;

        await fb.messaging().send({
          token,
          data: {
            type: 'ev_watch',
            stationId: statId,
            stationName,
            title: `⚡ ${stationName}`,
            body,
            newAvail: String(newAvail),
            prevAvail: String(prevAvail),
          },
          android: { priority: 'high' },
        });
        console.log(`[WATCH] 푸시: ${stationName}(${statId}) ${prevAvail}→${newAvail} → device=${deviceId}`);
      }
    } catch (e) {
      console.error(`[WATCH] 세션 체크 실패 ${statId}:`, e.message);
    }
  }
}

module.exports = { getStationsAround, getStationDetail, getChargersByZcode, buildGeoIndex, setWarmingUp, refreshAllStatusCaches };
