const axios = require('axios');
const { parseStringPromise } = require('xml2js');
const { getCache, setCache, geoAdd, geoSearch, hSetBulk, hmGet, expire, del, rename, keyExists } = require('../middleware/cache');

const BASE_URL = 'http://apis.data.go.kr/B552584/EvCharger';
const API_KEY = process.env.EV_API_KEY;
const EV_CACHE_TTL = 30 * 60;     // zcode 풀 데이터 캐시: 30분 (geo 인덱스 구축용)
const GEO_TTL      = 24 * 60 * 60; // geo 인덱스: 24시간 (정적 데이터)
const STATUS_TTL   = 3 * 60;       // 충전 상태 캐시: 3분

const GEO_KEY  = 'ev:geo';
const DATA_KEY = 'ev:stations:data'; // hash: statId → JSON (정적 데이터)

// ─── 환경부 EV API 호출 ───
async function callEvApi(endpoint, params = {}) {
  const callParams = { ...params };
  delete callParams.serviceKey;
  console.log(`[EV API] →  ${endpoint}`, callParams);
  const t0 = Date.now();
  try {
    const res = await axios.get(`${BASE_URL}/${endpoint}`, {
      params: { serviceKey: API_KEY, numOfRows: 9999, ...params },
      timeout: 20000,
      responseType: 'text',
    });

    let data = res.data;
    if (typeof data === 'string' && data.includes('<?xml')) {
      const parsed = await parseStringPromise(data, { explicitArray: false, ignoreAttrs: true });
      const body = parsed?.response?.body ?? parsed;
      console.log(`[EV API] ←  ${endpoint} XML (${Date.now() - t0}ms)`);
      return body;
    }
    if (typeof data === 'string') data = JSON.parse(data);
    const items = data?.items?.[0]?.item ?? data?.items?.item;
    const count = Array.isArray(items) ? items.length : (items ? 1 : 0);
    console.log(`[EV API] ←  ${endpoint} JSON ${count}건 (${Date.now() - t0}ms)`);
    return data;
  } catch (err) {
    console.error(`[EV API] ✗  ${endpoint} (${Date.now() - t0}ms):`, err.message);
    throw err;
  }
}

function extractItems(body) {
  const raw = body?.items?.[0]?.item ?? body?.items?.item;
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
    while (true) {
      const data = await callEvApi('getChargerInfo', { zcode, pageNo });
      const items = extractItems(data);
      allItems.push(...items);
      console.log(`[EV Cache] zcode=${zcode} page=${pageNo} ${items.length}건 (누적 ${allItems.length}건)`);
      if (items.length < 9999 || pageNo >= 10) break;
      pageNo++;
      await new Promise(r => setTimeout(r, 300));
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

// ─── 충전 상태 캐시 (3분 TTL, zcode 단위) ───
const inflightStatus = new Map();

async function getStatusByZcode(zcode) {
  const cacheKey = `ev:status:zcode:${zcode}`;
  const cached = await getCache(cacheKey);
  if (cached) {
    console.log(`[EV Status] HIT zcode=${zcode} (${cached.length}건)`);
    return cached;
  }

  if (inflightStatus.has(zcode)) {
    return inflightStatus.get(zcode);
  }

  const promise = (async () => {
    try {
      const data = await callEvApi('getChargerStatus', { zcode });
      const items = extractItems(data);
      if (items.length > 0) {
        await setCache(cacheKey, items, STATUS_TTL);
        console.log(`[EV Status] SET zcode=${zcode} ${items.length}건 (TTL=${STATUS_TTL}s)`);
      }
      return items;
    } catch (err) {
      console.error(`[EV Status] zcode=${zcode} 실패:`, err.message);
      // 실패 시 60초간 재시도 억제 (타임아웃 폭주 방지)
      await setCache(cacheKey, [], 60).catch(() => {});
      return [];
    }
  })();

  inflightStatus.set(zcode, promise);
  try {
    return await promise;
  } finally {
    inflightStatus.delete(zcode);
  }
}

// lat/lng → zcode 역산 (REGIONS 배열 활용)
function getZcodeForLatLng(lat, lng) {
  const region = REGIONS.find(r =>
    lat >= r.latMin && lat <= r.latMax &&
    lng >= r.lngMin && lng <= r.lngMax
  );
  return region?.zcode ?? null;
}

// 반경이 걸치는 zcode 목록 반환
function getZcodesForArea(lat, lng, radius) {
  const latDelta = radius / 111000;
  const lngDelta = radius / (111000 * Math.cos(lat * Math.PI / 180));
  return REGIONS
    .filter(r =>
      lat + latDelta >= r.latMin && lat - latDelta <= r.latMax &&
      lng + lngDelta >= r.lngMin && lng - lngDelta <= r.lngMax
    )
    .map(r => r.zcode);
}

// 상태 맵 생성 (캐시된 데이터만 즉시 사용, 미캐시 zcode는 백그라운드 갱신)
async function buildStatusMap(zcodes) {
  if (zcodes.length === 0) return {};

  const map = {};
  const missedZcodes = [];

  // 캐시 히트 여부 먼저 확인 (API 호출 없이)
  await Promise.all(zcodes.map(async (z) => {
    const cached = await getCache(`ev:status:zcode:${z}`);
    if (cached) {
      for (const item of cached) {
        map[`${item.statId}_${item.chgerId}`] = {
          stat: parseInt(item.stat || '9'),
          statUpdDt: item.statUpdDt,
        };
      }
    } else {
      missedZcodes.push(z);
    }
  }));

  // 캐시 미스된 zcode는 백그라운드에서 순차 갱신 (동시 요청 → rate limit 방지)
  if (missedZcodes.length > 0) {
    console.log(`[EV Status] 백그라운드 갱신 zcode=${missedZcodes.join(',')}`);
    (async () => {
      for (const z of missedZcodes) {
        await getStatusByZcode(z).catch(() => {});
      }
    })();
  }

  return map;
}

// 충전소 목록에 실시간 상태 덧씌우기
function overlayStatus(stations, statusMap) {
  for (const s of stations) {
    for (const c of s.chargers) {
      const key = `${s.statId}_${c.chgerId}`;
      if (statusMap[key]) {
        c.stat = statusMap[key].stat;
        c.statUpdDt = statusMap[key].statUpdDt;
      }
    }
    s.availableCount = s.chargers.filter(c => c.stat === 2).length;
    s.chargingCount  = s.chargers.filter(c => c.stat === 3).length;
  }
  return stations;
}

// ─── Geo 인덱스 구축 ───
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
        kind: c.kind,
        kindDetail: c.kindDetail,
        useTime: c.useTime || '24시간',
        parkingFree: c.parkingFree === 'Y',
        chargers: [],
      });
    }
    // geo 인덱스에는 정적 데이터만 저장 (stat 제외)
    stationMap.get(c.statId).chargers.push({
      chgerId: c.chgerId,
      chgerType: c.chgerType,
      output: parseInt(c.output || '7'),
      stat: parseInt(c.stat || '9'),       // 초기값 (status 캐시로 덮어씀)
      statUpdDt: c.statUpdDt,
      unitPrice: c.unitPrice ? parseInt(c.unitPrice) : null,
    });
  }

  const stations = [...stationMap.values()];
  if (stations.length === 0) {
    console.warn('[EV Geo] 구축할 데이터 없음');
    return 0;
  }

  const GEO_NEW  = GEO_KEY  + ':new';
  const DATA_NEW = DATA_KEY + ':new';
  await del(GEO_NEW);
  await del(DATA_NEW);

  const geoMembers = stations.map(s => ({ longitude: s.lng, latitude: s.lat, member: s.statId }));
  await geoAdd(GEO_NEW, geoMembers);

  const dataFields = {};
  for (const s of stations) dataFields[s.statId] = JSON.stringify(s);
  await hSetBulk(DATA_NEW, dataFields);

  await expire(GEO_NEW,  GEO_TTL);
  await expire(DATA_NEW, GEO_TTL);
  await rename(GEO_NEW,  GEO_KEY);
  await rename(DATA_NEW, DATA_KEY);

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

  // 상태 맵 병렬 조회 시작 (geo 검색과 동시에)
  const zcodes = getZcodesForArea(lat, lng, radius);
  const statusMapPromise = buildStatusMap(zcodes);

  // 1순위: Redis GEOSEARCH
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
        const s = JSON.parse(dataStrings[i]);
        const dist = haversineDistance(lat, lng, s.lat, s.lng);
        stations.push({ ...s, distance: Math.round(dist) });
      }
      stations.sort((a, b) => a.distance - b.distance);

      // 실시간 상태 덧씌우기
      const statusMap = await statusMapPromise;
      overlayStatus(stations, statusMap);

      console.log(`[EV Around] GEOSEARCH+Status ${stations.length}건 (${Date.now() - t0}ms)`);
      return stations;
    }
  }

  // 2순위: zcode fallback
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
  // 정적 정보: 캐시 활용 (geo 인덱스 or API)
  const staticKey = `ev:station:static:${statId}`;
  let staticData = await getCache(staticKey);

  if (!staticData) {
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
      kind: info.kind,
      kindDetail: info.kindDetail,
      chargers: infoList.map(s => ({
        chgerId: s.chgerId,
        chgerType: s.chgerType,
        output: parseInt(s.output || '7'),
        stat: parseInt(s.stat || '9'),
        statUpdDt: s.statUpdDt,
        lastTsdt: s.lastTsdt,
        lastTedt: s.lastTedt,
        nowTsdt: s.nowTsdt,
        unitPrice: s.unitPrice ? parseInt(s.unitPrice) : null,
      })),
    };
    staticData.unitPrice = staticData.chargers.find(c => c.unitPrice)?.unitPrice ?? null;
    staticData.totalCount = staticData.chargers.length;
    await setCache(staticKey, staticData, GEO_TTL); // 정적 정보는 24시간
  }

  // 실시간 상태: 목록과 동일한 zcode 캐시 사용 → 불일치 없음
  const zcode = getZcodeForLatLng(staticData.lat, staticData.lng);
  if (zcode) {
    const statusItems = await getStatusByZcode(zcode);
    const statusMap = {};
    for (const item of statusItems) {
      if (item.statId === statId) {
        statusMap[item.chgerId] = {
          stat: parseInt(item.stat || '9'),
          statUpdDt: item.statUpdDt,
        };
      }
    }
    for (const c of staticData.chargers) {
      if (statusMap[c.chgerId]) {
        c.stat = statusMap[c.chgerId].stat;
        c.statUpdDt = statusMap[c.chgerId].statUpdDt;
      }
    }
  }

  return {
    ...staticData,
    totalCount: staticData.chargers.length,
    availableCount: staticData.chargers.filter(c => c.stat === 2).length,
    chargingCount:  staticData.chargers.filter(c => c.stat === 3).length,
  };
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

module.exports = { getStationsAround, getStationDetail, getChargersByZcode, buildGeoIndex };
