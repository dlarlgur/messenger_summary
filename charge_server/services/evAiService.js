const { geoSearch, hmGet } = require('../middleware/cache');
const { applyEvNavCoordOverride } = require('./evNavCoordOverrides');
const { lookupPrice } = require('./evPriceService');
const { fetchTmapRoute, fetchTmapPoisAroundRoute } = require('./tmapRoute');
const { fetchNaverDrivingRoute } = require('./naverDrivingRoute');
const { generateText } = require('./geminiClient');

const DATA_KEY = 'ev:stations:data';
const GEO_KEY  = 'ev:geo';  // evApi.js와 동일한 키

// 환경부 API chgerType 코드 (evPriceService.js 기준)
// 완속: 02(AC완속, J1772 5핀) 만
// 급속: 01(DC차데모), 03(DC차데모+AC3상), 04(DC콤보), 05(DC차데모+DC콤보),
//        06(DC차데모+AC3상+DC콤보), 07(AC3상), 08~11 기타 급속
const FAST_TYPES = new Set(['01','03','04','05','06','07','09','10','11']);
const SLOW_TYPES = new Set(['02','08']); // 08=DC콤보(완속)

// 경로를 intervalM 간격으로 샘플링
function resamplePath(pathPoints, intervalM, maxSamples = 60) {
  if (!pathPoints || pathPoints.length < 2) return pathPoints || [];
  const result = [pathPoints[0]];
  let acc = 0;
  for (let i = 1; i < pathPoints.length; i++) {
    acc += haversineM(pathPoints[i-1].lat, pathPoints[i-1].lng, pathPoints[i].lat, pathPoints[i].lng);
    if (acc >= intervalM) {
      result.push(pathPoints[i]);
      acc = 0;
      if (result.length >= maxSamples) break;
    }
  }
  const last = pathPoints[pathPoints.length - 1];
  if (result[result.length - 1] !== last) result.push(last);
  return result;
}

function haversineM(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** 필터·정렬 완료 후 후보만 TMAP POI vs Redis 좌표·주소 비교 로그 */
function logFinalTmapVsRedis(withPrice, tmapBestPoiByStatId, tag) {
  console.log(`${tag}[TMAP↔Redis 최종] 필터·정렬 후 후보 ${withPrice.length}곳`);
  let rank = 0;
  for (const s of withPrice) {
    rank++;
    const id = s.statId;
    const t = tmapBestPoiByStatId.get(id);
    const rLat = parseFloat(s.lat);
    const rLng = parseFloat(s.lng);
    const rLatS = Number.isFinite(rLat) ? rLat.toFixed(6) : String(s.lat);
    const rLngS = Number.isFinite(rLng) ? rLng.toFixed(6) : String(s.lng);
    const rAddr = String(s.addr || '').replace(/\s+/g, ' ').trim();
    if (t) {
      console.log(
        `${tag}[TMAP↔Redis 최종] #${rank} statId=${id} ${s.statNm || ''}\n` +
          `  TMAP: (${t.lat.toFixed(6)},${t.lng.toFixed(6)}) address="${(t.addr || '').slice(0, 160)}" name="${t.name}"\n` +
          `  Redis: (${rLatS},${rLngS}) address="${rAddr.slice(0, 160)}" | POI↔Redis직선≈${Math.round(t.distM)}m`,
      );
    } else {
      console.log(
        `${tag}[TMAP↔Redis 최종] #${rank} statId=${id} ${s.statNm || ''}\n` +
          `  TMAP: (없음 — C03 POI geo매칭 없이 경로 지오 등으로만 유입)\n` +
          `  Redis: (${rLatS},${rLngS}) address="${rAddr.slice(0, 160)}"`,
      );
    }
  }
}

// 경로 포인트 따라 주행가능거리 안의 충전소 수집
function stationsWithinReach(stations, pathPoints, reachableM) {
  if (!pathPoints || pathPoints.length < 2) return stations;

  // 경로 누적 거리 계산
  const cumulDist = [0];
  for (let i = 1; i < pathPoints.length; i++) {
    const d = haversineM(
      pathPoints[i-1].lat, pathPoints[i-1].lng,
      pathPoints[i].lat, pathPoints[i].lng
    );
    cumulDist.push(cumulDist[i-1] + d);
  }
  const totalRouteM = cumulDist[cumulDist.length - 1];
  const effectiveReachM = Math.min(reachableM, totalRouteM);

  console.log(`[stationsWithinReach] totalRouteM=${(totalRouteM/1000).toFixed(1)}km reachableM=${(reachableM/1000).toFixed(1)}km effectiveReachM=${(effectiveReachM/1000).toFixed(1)}km stations=${stations.length}`);

  let dropByDist = 0, dropByRoute = 0;
  const result = stations.filter(s => {
    // 경로상 가장 가까운 포인트 찾기
    let minDistToRoute = Infinity;
    let nearestPathIdx = 0;
    for (let i = 0; i < pathPoints.length; i++) {
      const d = haversineM(s.lat, s.lng, pathPoints[i].lat, pathPoints[i].lng);
      if (d < minDistToRoute) {
        minDistToRoute = d;
        nearestPathIdx = i;
      }
    }
    const cumulAtNearest = cumulDist[nearestPathIdx];
    const passDistCheck = cumulAtNearest <= effectiveReachM;
    const passRouteCheck = minDistToRoute <= 3000;
    if (!passDistCheck) dropByDist++;
    else if (!passRouteCheck) dropByRoute++;
    return passDistCheck && passRouteCheck;
  });

  console.log(`[stationsWithinReach] 통과=${result.length} 탈락(누적거리초과)=${dropByDist} 탈락(경로3km초과)=${dropByRoute}`);
  return result;
}

// 이용제한 필터
function isRestricted(s) {
  // limitYn='Y' → 이용제한 있음으로 명시 → 제외
  if (s.limitYn === 'Y') return true;
  const limit = (s.limitDetail || '').toLowerCase();
  const note  = (s.note || '').toLowerCase();
  if (limit.includes('외부인') || note.includes('외부인')) return true;
  if (limit.includes('이용불가') || note.includes('이용불가')) return true;
  return false;
}

// 해당 충전 타입 보유 여부
function hasChargerType(station, chargerType) {
  const types = chargerType === 'FAST' ? FAST_TYPES : SLOW_TYPES;
  return (station.chargers || []).some(c => types.has(c.chgerType));
}

// 가용 충전기 수 (타입 필터 적용)
function availableCount(station, chargerType) {
  const types = chargerType === 'FAST' ? FAST_TYPES : SLOW_TYPES;
  return (station.chargers || []).filter(
    c => types.has(c.chgerType) && c.stat === 2
  ).length;
}

// 총 충전기 수 (타입 필터 적용)
function totalCount(station, chargerType) {
  const types = chargerType === 'FAST' ? FAST_TYPES : SLOW_TYPES;
  return (station.chargers || []).filter(c => types.has(c.chgerType)).length;
}

// 충전중 중 가장 오래된 nowTsdt (분)
function oldestChargingMinutes(station, chargerType) {
  const types = chargerType === 'FAST' ? FAST_TYPES : SLOW_TYPES;
  const charging = (station.chargers || [])
    .filter(c => types.has(c.chgerType) && c.stat === 3 && c.nowTsdt)
    .map(c => c.nowTsdt)
    .sort(); // 오래된 순
  if (!charging.length) return null;

  // nowTsdt 형식: "20240101120000" (YYYYMMDDHHmmss)
  const oldest = charging[0];
  if (oldest.length < 14) return null;
  const y = oldest.slice(0,4), mo = oldest.slice(4,6), d = oldest.slice(6,8);
  const h = oldest.slice(8,10), mi = oldest.slice(10,12), s = oldest.slice(12,14);
  const dt = new Date(`${y}-${mo}-${d}T${h}:${mi}:${s}`);
  const diffMin = Math.round((Date.now() - dt.getTime()) / 60000);
  return diffMin > 0 ? diffMin : null;
}

// 경로와의 최근접 포인트 거리 + 출발지에서 누적 거리 반환
function nearestRouteInfo(station, pathPoints, cumulDist) {
  let minDist = Infinity;
  let nearestIdx = 0;
  for (let i = 0; i < pathPoints.length; i++) {
    const d = haversineM(station.lat, station.lng, pathPoints[i].lat, pathPoints[i].lng);
    if (d < minDist) { minDist = d; nearestIdx = i; }
  }
  return {
    routeDistM: minDist,
    originDistM: cumulDist ? cumulDist[nearestIdx] : 0,
  };
}


// C001 고속도로 휴게소 그룹핑 — 동일 위치 다운영사 통합 (150m 이내)
function groupC001Stations(candidates) {
  const RADIUS_M = 300;
  const grouped = [];
  const used = new Set();

  for (let i = 0; i < candidates.length; i++) {
    if (used.has(i)) continue;
    const s = candidates[i];
    if (s.kindDetail !== 'C001') {
      grouped.push(s);
      continue;
    }
    used.add(i);
    const group = [s];
    const sLat = parseFloat(s.lat);
    const sLng = parseFloat(s.lng);
    for (let j = i + 1; j < candidates.length; j++) {
      if (used.has(j)) continue;
      const t = candidates[j];
      if (t.kindDetail !== 'C001') continue;
      if (haversineM(sLat, sLng, parseFloat(t.lat), parseFloat(t.lng)) <= RADIUS_M) {
        group.push(t);
        used.add(j);
      }
    }

    if (group.length === 1) {
      grouped.push(s);
    } else {
      const totalAvail = group.reduce((sum, m) => sum + (m.avail || 0), 0);
      const totalTotal = group.reduce((sum, m) => sum + (m.total || 0), 0);
      const bestPrice = group.reduce((best, m) => {
        const p = m.unitPrice;
        if (p == null) return best;
        return best == null ? p : Math.min(best, p);
      }, null);
      // 대표: 가용 많은 순 → 전체 많은 순
      const rep = group.reduce((a, b) =>
        (b.avail || 0) > (a.avail || 0) ? b :
        (b.avail || 0) === (a.avail || 0) && (b.total || 0) > (a.total || 0) ? b : a
      );
      grouped.push({
        ...rep,
        avail: totalAvail,
        total: totalTotal,
        unitPrice: bestPrice,
        grouped_count: group.length,
        grouped_stations: group.map(m => ({
          statId: m.statId,
          name: m.statNm,
          operator: m.busiNm,
          lat: m.lat,
          lng: m.lng,
          avail: m.avail,
          total: m.total,
          unitPrice: m.unitPrice,
          addr: m.addr,
        })),
      });
    }
  }
  return grouped;
}

// ── EV 충전소 스코어링 모델 ──────────────────────────────────────────────────────

/**
 * 도착 시점에 자리가 있을 확률 (포아송 과정 기반)
 * P = 1 - exp(-effective_avail / (α·popularity·ETA + β))
 *
 * α=0.3 : ETA 영향 가중치. 값 클수록 ETA에 더 민감 (자리 뺏길 확률 ↑)
 * β=1.0 : 분모 최솟값. ETA=0이어도 분모가 0이 되지 않도록 보정
 * freshness=0.8 : Redis 데이터 신선도 기본값 (명시적 타임스탬프 없음)
 */
function calcPSuccess(avail, etaMin, { popularity = 1.0, freshness = 0.8 } = {}) {
  const alpha = 0.3;
  const beta  = 1.0;
  const effectiveAvail = avail * freshness;
  if (effectiveAvail <= 0) return 0.05; // avail=0이어도 충전 완료 차 빠질 소량 확률
  return 1 - Math.exp(-effectiveAvail / (alpha * popularity * Math.max(etaMin, 0) + beta));
}

/**
 * SoC 기반 우회 페널티 — 배터리 낮을수록 우회 비용이 지수적으로 증가
 * C_detour = detour_min × (1 + k / max(SoC%, 5))
 *
 * k=0.5 : 배터리 민감도. SoC 10% → 페널티 6배, SoC 50% → 2배
 */
function calcDetourCost(detourMin, socPercent) {
  const k = 0.5;
  return (detourMin ?? 0) * (1 + k / Math.max(socPercent, 5));
}

/**
 * 최종 기대 효용 점수
 * Score = P·V_charge - C_detour - C_eta + (1-P)·V_fail_penalty
 *
 * V_CHARGE=100     : 충전 성공 효용
 * C_ETA_RATE=1.0   : 이동 시간 비용 (분당 1점)
 * V_FAIL_PENALTY=-30 : 만석으로 허탕 칠 때 페널티
 */
function calcEvScore({ pSuccess, detourMin, etaMin, socPercent }) {
  const V_CHARGE       = 100;
  const C_ETA_RATE     = 1.0;
  const V_FAIL_PENALTY = -30;
  const cDetour = calcDetourCost(detourMin, socPercent);
  const cEta    = etaMin * C_ETA_RATE;
  return pSuccess * V_CHARGE - cDetour - cEta + (1 - pSuccess) * V_FAIL_PENALTY;
}

/**
 * 다양성 Top-5 선택
 * 5가지 프로파일로 중복 없이 서로 다른 성격의 충전소를 추천
 *
 * optimal   🎯 최고 점수
 * safe      🟢 P_success ≥ 0.85 중 최고 점수 (실패 위험 최소)
 * efficient ⚡ 우회 ≤ 3분 중 최고 점수 (경로 이탈 최소)
 * fastest   🚀 P_success ≥ 0.5 중 ETA 최소 (가장 빨리 도착)
 * spacious  💎 avail ≥ 3 중 최고 점수 (여유 자리 우선)
 *
 * 각 프로파일에 맞는 후보가 없으면 score 순 다음 미사용 후보로 fallback
 */
function selectDiverseTop5(scoredCandidates) {
  const byScore = [...scoredCandidates].sort((a, b) => b.score - a.score);
  const used = new Set();

  const profiles = [
    { label: 'optimal',   pool: () => byScore },
    { label: 'safe',      pool: () => byScore.filter(c => c.pSuccess >= 0.85) },
    { label: 'efficient', pool: () => byScore.filter(c => (c.detour_time_min ?? 0) <= 3) },
    { label: 'fastest',   pool: () => [...byScore.filter(c => c.pSuccess >= 0.5)]
                                        .sort((a, b) => (a.etaMin ?? 999) - (b.etaMin ?? 999)) },
    { label: 'spacious',  pool: () => byScore.filter(c => c.avail >= 3) },
  ];

  const result = [];
  for (const profile of profiles) {
    const candidates = profile.pool();
    const found = candidates.find(c => !used.has(c.statId));
    const fallback = !found ? byScore.find(c => !used.has(c.statId)) : null;
    const pick = found || fallback;
    if (pick) {
      used.add(pick.statId);
      result.push({ ...pick, recommendation_label: profile.label });
    }
  }
  return result;
}

function isTmapMode() {
  return !!process.env.TMAP_APP_KEY;
}

async function getPathPoints(originLat, originLng, destLat, destLng) {
  try {
    if (isTmapMode()) {
      const r = await fetchTmapRoute({ originLat, originLng, destLat, destLng });
      return r?.path_points || null;
    } else {
      const r = await fetchNaverDrivingRoute({ startLat: originLat, startLng: originLng, goalLat: destLat, goalLng: destLng });
      return r?.path_points || null;
    }
  } catch { return null; }
}

// ── EV AI 추천 메시지 생성 ──────────────────────────────────────────────────────
async function generateEvUiMessage({ batteryPercent, reachableKm, recommended, totalCandidates }) {
  if (!recommended) return null;
  const name = recommended.statNm || '';
  const avail = recommended.avail ?? 0;
  const total = recommended.total ?? 0;
  const detourMin = recommended.detour_time_min ?? null;
  const unitPrice = recommended.unitPrice ?? null;

  function fallback() {
    const reachTxt = `**${Math.round(reachableKm)}km**`;
    const battTxt  = `**${Math.round(batteryPercent)}%**`;
    const availTxt = avail > 0 ? `현재 **${avail}자리** 이용 가능하고` : '현재 자리가 없지만 곧 자리가 날 수 있어';
    const detourTxt = detourMin != null && detourMin > 0
      ? ` 들르면 **${detourMin}분** 우회됩니다.`
      : ' 경로 이탈 없이 들를 수 있어요.';
    const priceTxt = unitPrice ? ` (${unitPrice.toLocaleString('ko-KR')}원/kWh)` : '';
    return `현재 배터리 ${battTxt}로 약 ${reachTxt} 주행 가능해요. 경로 내 충전소 ${totalCandidates}곳 중 ${name}이${priceTxt} ${availTxt}${detourTxt}`;
  }

  if (!process.env.GEMINI_API_KEY) return fallback();

  const prompt = [
    'EV 충전 어시스턴트다. 아래 데이터를 바탕으로 마크다운 형식의 한국어 추천 메시지를 1~2문장으로 작성하라.',
    '필수 규칙:',
    '1. 배터리%, 주행가능거리, 자리수, 우회시간(분)만 **굵게** 표시. 충전소 이름·가격은 굵게 쓰지 말 것.',
    '2. "현재 배터리 X%로 약 Ykm 주행 가능, 경로 내 N곳 중 [충전소명]이 자리가 가장 많아 추천" 형식.',
    '3. 1~2문장, 친근한 어투. 헤더(#)·코드블록 없이 본문만 출력.',
    '',
    `배터리: ${Math.round(batteryPercent)}%`,
    `주행가능거리: ${Math.round(reachableKm)}km`,
    `추천 충전소: ${name}`,
    `가용 자리: ${avail}/${total}`,
    detourMin != null ? `우회시간: ${detourMin}분` : '경로 이탈 없음',
    unitPrice ? `단가: ${unitPrice.toLocaleString('ko-KR')}원/kWh` : '',
    `경로 내 후보 수: ${totalCandidates}`,
  ].filter(Boolean).join('\n');

  try {
    const raw = await generateText(prompt);
    if (raw && raw.trim()) {
      // **bold**한국어 → **bold** 한국어 (flutter_markdown이 닫는 ** 뒤 바로 한글 오면 파싱 실패 방지)
      const text = raw.trim()
        .replace(/\\n/g, '\n')
        .replace(/\*\*([^*]+)\*\*([가-힣])/g, '**$1** $2');
      return text;
    }
  } catch (e) {
    console.warn('[Gemini][EV] 메시지 생성 실패:', e.message);
  }
  return fallback();
}

async function getNaverViaDurationMs(origin, waypoint, dest) {
  try {
    const r = await fetchNaverDrivingRoute({
      startLat: origin.lat, startLng: origin.lng,
      goalLat: dest.lat, goalLng: dest.lng,
      waypointLat: waypoint.lat, waypointLng: waypoint.lng,
    });
    return r?.duration_ms ?? null;
  } catch { return null; }
}

async function evAiRecommend({
  batteryPercent,
  batteryCapacityKwh,
  efficiencyKmPerKwh,
  chargerType = 'FAST',   // 'FAST' | 'SLOW'
  originLat, originLng,
  destLat, destLng,
  pathPoints: inputPathPoints,
  directDurationMs,       // 직접 경로 소요시간 (클라이언트에서 전달) → 우회 추가시간 계산용
  userSelect = false,     // true: 전체 후보 목록 반환 (사용자 선택 모드)
  highwayOnly = false,    // true: 고속도로 휴게소(kindDetail=C001)만 추천
}) {
  const TAG = '[evAiRecommend]';

  // 주행가능거리 (m)
  const reachableKm = (batteryPercent / 100) * batteryCapacityKwh * efficiencyKmPerKwh;
  const reachableM  = reachableKm * 1000;

  console.log(`${TAG} 입력: battery=${batteryPercent}% cap=${batteryCapacityKwh}kWh eff=${efficiencyKmPerKwh}km/kWh type=${chargerType} directDurationMs=${directDurationMs ?? 'null'}`);
  console.log(`${TAG} 주행가능거리: ${reachableKm.toFixed(1)}km (${Math.round(reachableM)}m)`);
  console.log(`${TAG} 출발(${originLat},${originLng}) → 목적지(${destLat},${destLng})`);

  // 경로 포인트
  const pathPoints = inputPathPoints ||
    await getPathPoints(originLat, originLng, destLat, destLng) || [
      { lat: originLat, lng: originLng },
      { lat: destLat, lng: destLng },
    ];

  console.log(`${TAG} 경로 포인트 수: ${pathPoints.length} (inputPathPoints=${!!inputPathPoints})`);

  // 경로 포인트로 전체 경로 거리 계산
  let totalRouteM = 0;
  for (let i = 1; i < pathPoints.length; i++) {
    totalRouteM += haversineM(pathPoints[i-1].lat, pathPoints[i-1].lng, pathPoints[i].lat, pathPoints[i].lng);
  }
  console.log(`${TAG} 경로 총 거리: ${(totalRouteM/1000).toFixed(1)}km`);

  // ── 충전소 ID 수집 ──────────────────────────────────────────────────────────
  // TMAP C03: count=100 제한으로 도심 구간에서 100개 소진 → 경로를 N구간으로 나눠 각각 조회
  const stationIdSet = new Set();

  // 경로를 구간별로 분할해서 TMAP C03 조회 (전체 경로를 커버)
  const SEGMENT_COUNT = 3; // 경로를 3구간으로 나눔
  const segSize = Math.ceil(pathPoints.length / SEGMENT_COUNT);
  const tmapPromises = [];
  for (let i = 0; i < SEGMENT_COUNT; i++) {
    const start = i * segSize;
    const end = Math.min(start + segSize + 1, pathPoints.length); // 1포인트 겹치게
    const segPoints = pathPoints.slice(start, end);
    if (segPoints.length < 2) continue;
    tmapPromises.push(
      fetchTmapPoisAroundRoute({ pathPoints: segPoints, radiusM: 2000, count: 100, searchCategory: 'C03' })
    );
  }
  const tmapSegResults = await Promise.all(tmapPromises);
  const allTmapPois = tmapSegResults.flat();
  console.log(`${TAG} TMAP C03 경로상 EV POI: ${allTmapPois.length}개 (${SEGMENT_COUNT}구간 합산)`);

  // TMAP POI 좌표 → Redis statId 매칭 (200m 반경) + statId별 가장 가까운 TMAP POI 기록(최종 로그용)
  const tmapBestPoiByStatId = new Map();
  const tmapSourceIds = new Set(); // TMAP에서 수집된 statId 추적
  for (const poi of allTmapPois) {
    // 반경 50m: 200m에서 줄임 — 고속도로 반대방향 휴게소(150m 거리)가 딸려오는 문제 방지
    const ids = await geoSearch(GEO_KEY, poi.lng, poi.lat, 50) || [];
    if (ids.length) {
      const rows = await hmGet(DATA_KEY, ids);
      const tmapAddr = [poi.roadName, poi.address].filter(Boolean).join(' | ') || '';
      for (let j = 0; j < ids.length; j++) {
        if (!rows[j]) continue;
        let s;
        try {
          s = JSON.parse(rows[j]);
        } catch {
          continue;
        }
        const slat = parseFloat(s.lat);
        const slng = parseFloat(s.lng);
        if (!Number.isFinite(slat) || !Number.isFinite(slng)) continue;
        const distM = haversineM(poi.lat, poi.lng, slat, slng);
        const sid = ids[j];
        const prev = tmapBestPoiByStatId.get(sid);
        if (!prev || distM < prev.distM) {
          tmapBestPoiByStatId.set(sid, {
            name: poi.name || '',
            lat: poi.lat,
            lng: poi.lng,
            addr: tmapAddr,
            distM,
          });
        }
        // 고속도로 휴게소(kindDetail=C001) TMAP 수집 로그
        if (s.kindDetail === 'C001') {
          console.log(`${TAG} [TMAP-C001] ${s.statNm} (${slat.toFixed(5)},${slng.toFixed(5)}) ← TMAP POI "${poi.name}" dist=${Math.round(distM)}m`);
        }
      }
    }
    for (const id of ids) { stationIdSet.add(id); tmapSourceIds.add(id); }
  }
  console.log(`${TAG} TMAP→Redis 매칭: ${stationIdSet.size}개 statId (POI별 최근접 맵 ${tmapBestPoiByStatId.size}개)`);

  // highwayOnly=false 시: Redis GeoSearch로 경로 주변 추가 탐색
  if (!highwayOnly) {
    const SAMPLE_INTERVAL_M = 3000;
    const SEARCH_RADIUS_M   = 3000;
    const samplePoints = resamplePath(pathPoints, SAMPLE_INTERVAL_M);
    console.log(`${TAG} 경로 GeoSearch: ${samplePoints.length}개 포인트 (간격 ${SAMPLE_INTERVAL_M/1000}km, 반경 ${SEARCH_RADIUS_M/1000}km)`);
    for (const p of samplePoints) {
      const ids = await geoSearch(GEO_KEY, p.lng, p.lat, SEARCH_RADIUS_M) || [];
      for (const id of ids) {
        const isNew = !stationIdSet.has(id);
        stationIdSet.add(id);
        // GeoSearch에서 새로 추가된 고속도로 휴게소만 로그
        if (isNew) {
          const row = (await hmGet(DATA_KEY, [id]))[0];
          if (row) {
            try {
              const s = JSON.parse(row);
              if (s.kindDetail === 'C001') {
                console.log(`${TAG} [GEO-C001] ${s.statNm} (${s.lat},${s.lng}) ← GeoSearch 포인트(${p.lat.toFixed(5)},${p.lng.toFixed(5)}) — TMAP에 없던 것`);
              }
            } catch {}
          }
        }
      }
    }
  }

  const allIds = [...stationIdSet];
  console.log(`${TAG} 최종 수집: ${allIds.length}개 고유 충전소 ID (highwayOnly=${highwayOnly})`);

  let stations = [];
  if (allIds.length > 0) {
    const dataStrings = await hmGet(DATA_KEY, allIds);
    for (let i = 0; i < allIds.length; i++) {
      if (!dataStrings[i]) continue;
      const s = JSON.parse(dataStrings[i]);
      stations.push(applyEvNavCoordOverride(s));
    }
  }
  console.log(`${TAG} Redis 로드: ${stations.length}개 충전소`);

  // 1. 주행가능거리 이내 + 경로 근처
  const reachable = stationsWithinReach(stations, pathPoints, reachableM);
  console.log(`${TAG} 경로+거리 필터 후: ${reachable.length}개 (탈락 ${stations.length - reachable.length}개)`);

  // 2. 이용제한 제외
  const notRestricted = reachable.filter(s => !isRestricted(s));
  const filteredOutCount = reachable.length - notRestricted.length;
  console.log(`${TAG} 이용제한 제외 후: ${notRestricted.length}개 (제외 ${filteredOutCount}개)`);

  // 3. 선택한 충전 타입 보유한 곳만
  const typeFiltered = notRestricted.filter(s => hasChargerType(s, chargerType));
  console.log(`${TAG} 충전타입(${chargerType}) 필터 후: ${typeFiltered.length}개 (탈락 ${notRestricted.length - typeFiltered.length}개)`);

  // 3-1. 고속도로만 옵션: kindDetail=C001 (고속도로 휴게소)만 통과
  const hwFiltered = highwayOnly
    ? typeFiltered.filter(s => s.kindDetail === 'C001')
    : typeFiltered;

  // 3-2. 방향 필터: 상행/하행 반대 방향 휴게소 제외
  // 서울 위도(37.5) 기준으로 출발→도착 방향이 '하행(서울에서 멀어짐)'인지 '상행(서울로)'인지 판단
  const SEOUL_LAT = 37.5;
  const originDistToSeoul = Math.abs(originLat - SEOUL_LAT);
  const destDistToSeoul   = Math.abs(destLat   - SEOUL_LAT);
  const isGoingDownstream = destDistToSeoul > originDistToSeoul; // 하행(서울에서 멀어짐)
  const isGoingUpstream   = destDistToSeoul < originDistToSeoul; // 상행(서울로)
  const candidates = hwFiltered.filter(s => {
    const name = (s.statNm || '').trim();
    if (isGoingDownstream && name.includes('상행')) return false; // 하행 중 상행 휴게소 제외
    if (isGoingUpstream   && name.includes('하행')) return false; // 상행 중 하행 휴게소 제외
    return true;
  });
  const dirDropped = hwFiltered.length - candidates.length;
  if (dirDropped > 0) console.log(`${TAG} 방향 필터(${isGoingDownstream?'하행':'상행'}) 후: ${candidates.length}개 (제외 ${dirDropped}개)`);
  if (highwayOnly) {
    console.log(`${TAG} 고속도로만 필터 후: ${candidates.length}개 (탈락 ${typeFiltered.length - candidates.length}개)`);
    // 탈락된 충전소 kindDetail 샘플 로그
    const dropped = typeFiltered.filter(s => s.kindDetail !== 'C001');
    const kindGroups = {};
    dropped.forEach(s => {
      const k = `${s.kindDetail}(${s.kind})`;
      kindGroups[k] = (kindGroups[k] || 0) + 1;
    });
    console.log(`${TAG} 탈락 kindDetail 분포:`, JSON.stringify(kindGroups));
    dropped.slice(0, 10).forEach(s =>
      console.log(`${TAG}   탈락: ${s.statNm} kind=${s.kind} kindDetail=${s.kindDetail}`)
    );
  }

  if (candidates.length === 0) {
    // 탈락 원인 샘플 로그
    if (notRestricted.length > 0 && notRestricted.length <= 5) {
      notRestricted.forEach(s => {
        const types = (s.chargers || []).map(c => c.chgerType).join(',');
        console.log(`${TAG}   타입 탈락 샘플: ${s.statNm} chgerTypes=[${types}]`);
      });
    }
    if (reachable.length > 0 && reachable.length <= 10) {
      reachable.forEach(s => {
        const routeDist = s._routeDist ? `${Math.round(s._routeDist)}m` : '?';
        console.log(`${TAG}   reachable 샘플: ${s.statNm} (${s.lat},${s.lng}) routeDist=${routeDist}`);
      });
    }
    return {
      reachable_distance_km: Math.round(reachableKm * 10) / 10,
      charger_type: chargerType,
      recommended: null,
      alternatives: [],
      filtered_out_count: filteredOutCount,
      message: highwayOnly
        ? '주행 가능 거리 내에 고속도로 충전소가 없어요.'
        : '주행 가능 거리 내에 이용 가능한 충전소가 없어요.',
    };
  }

  // 4. 가격 보강
  // 경로 누적 거리 (출발지에서 각 포인트까지)
  const routeCumulDist = [0];
  for (let i = 1; i < pathPoints.length; i++) {
    routeCumulDist.push(routeCumulDist[i-1] + haversineM(
      pathPoints[i-1].lat, pathPoints[i-1].lng,
      pathPoints[i].lat, pathPoints[i].lng,
    ));
  }
  const totalRouteMForEta = routeCumulDist[routeCumulDist.length - 1] || 0;

  const withPrice = candidates.map(s => {
    const price = lookupPrice(s.busiId, s.chargers || []);
    const unitPrice = chargerType === 'FAST' ? price.fast : price.slow;
    const avail = availableCount(s, chargerType);
    const total = totalCount(s, chargerType);
    const charging = (s.chargers || []).filter(c =>
      (chargerType === 'FAST' ? FAST_TYPES : SLOW_TYPES).has(c.chgerType) && c.stat === 3
    ).length;
    const oldest = oldestChargingMinutes(s, chargerType);
    const { routeDistM, originDistM } = nearestRouteInfo(s, pathPoints, routeCumulDist);
    return { ...s, unitPrice, avail, total, charging, oldest, routeDistM, originDistM };
  });

  // 상태 메시지 (정렬 전에 선언 — userSelect 블록에서도 사용)
  const makeMessage = (s) => {
    if (s.avail > 1) return `지금 ${s.avail}자리 여유 있어요`;
    if (s.avail === 1) return '자리 1개 남았어요. 서두르세요!';
    if (s.oldest != null) return `만석이지만 ${s.oldest}분째 충전 중인 차량이 있어 자리 날 가능성이 높아요`;
    if (chargerType === 'FAST') return '현재 만석이지만 급속 충전(30~60분) 특성상 도착 전 자리 날 수 있어요';
    return '현재 만석이에요';
  };

  // 5. 정렬: 경로 이탈 최소(routeDistM 오름차순) → 가용수 내림차순 → 가격 오름차순
  // - 고속도로 휴게소(경로에서 50~300m)는 자연스럽게 앞으로 옴
  // - 국도 주행 시 도로변 충전소(경로에서 50~200m)도 자연스럽게 앞으로 옴
  // - 경로에서 1km 이상 벗어난 충전소는 뒤로 밀림
  // → 임계값 하드코딩 없이 도로 타입에 무관하게 동작
  withPrice.sort((a, b) => {
    // routeDistM 300m 단위로 그룹핑해서 같은 그룹 안에선 가용수 우선
    // (너무 미세한 거리 차이로 가용수 높은 충전소가 밀리는 것 방지)
    const aGroup = Math.floor(a.routeDistM / 300);
    const bGroup = Math.floor(b.routeDistM / 300);
    if (aGroup !== bGroup) return aGroup - bGroup;
    if (b.avail !== a.avail) return b.avail - a.avail;
    const pa = a.unitPrice || 99999;
    const pb = b.unitPrice || 99999;
    return pa - pb;
  });

  logFinalTmapVsRedis(withPrice, tmapBestPoiByStatId, TAG);

  // C001 고속도로 휴게소 그룹핑 (동일 위치 다운영사 통합)
  const groupedWithPrice = groupC001Stations(withPrice);
  const groupCount = groupedWithPrice.filter(s => s.grouped_count > 1).length;
  if (groupCount > 0) {
    console.log(`${TAG} C001 그룹핑: ${groupCount}개 그룹 (원본 ${withPrice.length}개 → ${groupedWithPrice.length}개)`);
  }

  // 사용자 선택 모드: 경유 시간 계산 없이 전체 목록 반환
  if (userSelect) {
    return {
      reachable_distance_km: Math.round(reachableKm * 10) / 10,
      charger_type: chargerType,
      candidates: withPrice.slice(0, 50).map(s => ({
        statId: s.statId,
        name: s.statNm,
        address: s.addr,
        lat: s.lat,
        lng: s.lng,
        operator: s.busiNm,
        available_count: s.avail,
        total_count: s.total,
        charging_count: s.charging,
        unit_price: s.unitPrice,
        origin_distance_m: Math.round(s.originDistM ?? 0),
        origin_eta_min: (() => {
          if (!s.originDistM || !directDurationMs || !totalRouteMForEta) return null;
          const ratio = Math.min(s.originDistM / totalRouteMForEta, 1.0);
          return Math.round(directDurationMs / 60000 * ratio);
        })(),
        route_distance_m: Math.round(s.routeDistM),
        status_message: makeMessage(s),
        limitYn: s.limitYn,
      })),
      filtered_out_count: filteredOutCount,
      total_candidates: candidates.length,
    };
  }

  // 6. 경유 시간 계산 (top 10) — 다양성 선정 풀 확보용
  const top5 = groupedWithPrice.slice(0, 10);
  const origin = { lat: originLat, lng: originLng };
  const dest   = { lat: destLat,   lng: destLng };

  // directDurationMs 미제공 시 서버에서 직접 계산
  let resolvedDirectMs = directDurationMs ?? null;
  if (resolvedDirectMs == null) {
    try {
      const directR = await fetchNaverDrivingRoute({ startLat: originLat, startLng: originLng, goalLat: destLat, goalLng: destLng });
      if (directR?.duration_ms != null) {
        resolvedDirectMs = directR.duration_ms;
        console.log(`${TAG} 직접경로 서버 계산: ${Math.round(resolvedDirectMs / 60000)}분`);
      }
    } catch (_) {}
  }

  const withDetour = await Promise.all(top5.map(async s => {
    const viaMs = await getNaverViaDurationMs(origin, { lat: s.lat, lng: s.lng }, dest);
    let detourMin = null;
    if (viaMs != null && resolvedDirectMs != null) {
      const addedMs = viaMs - resolvedDirectMs;
      detourMin = Math.max(0, Math.round(addedMs / 60000));
      console.log(`${TAG} 우회계산 ${s.statNm}: via=${Math.round(viaMs/60000)}분 direct=${Math.round(resolvedDirectMs/60000)}분 → +${detourMin}분`);
    }
    return { ...s, detour_time_min: detourMin };
  }));

  // 7. 스코어링 — 각 후보의 도착 시점 성공 확률 + 기대 효용 계산
  const scored = withDetour.map(s => {
    const etaMin = (() => {
      if (!s.originDistM || !resolvedDirectMs || !totalRouteMForEta) return 10;
      const ratio = Math.min(s.originDistM / totalRouteMForEta, 1.0);
      return Math.round(resolvedDirectMs / 60000 * ratio);
    })();
    const pSuccess = calcPSuccess(s.avail, etaMin);
    const score    = calcEvScore({ pSuccess, detourMin: s.detour_time_min, etaMin, socPercent: batteryPercent });
    return { ...s, etaMin, pSuccess, score };
  });

  // 8. 다양성 Top-5 선정
  const diverse = selectDiverseTop5(scored);
  console.log(
    `${TAG} 다양성 Top-${diverse.length}: ` +
    diverse.map(s => `${s.statNm}(${s.recommendation_label} score=${s.score.toFixed(1)} P=${s.pSuccess.toFixed(2)} detour=${s.detour_time_min ?? '?'}분)`).join(' / ')
  );

  // 9. 응답 포맷
  const format = (s) => {
    // 출발지→충전소 예상 소요시간: 전체 경로 시간 기준 비율로 추정
    let originEtaMin = null;
    if (s.originDistM > 0 && resolvedDirectMs > 0 && totalRouteMForEta > 0) {
      const ratio = Math.min(s.originDistM / totalRouteMForEta, 1.0);
      originEtaMin = Math.round(resolvedDirectMs / 60000 * ratio);
    }
    return {
      statId: s.statId,
      name: s.statNm,
      address: s.addr,
      lat: s.lat,
      lng: s.lng,
      operator: s.busiNm,
      available_count: s.avail,
      total_count: s.total,
      charging_count: s.charging,
      unit_price: s.unitPrice,
      detour_time_min: s.detour_time_min ?? null,
      oldest_charging_min: s.oldest ?? null,
      origin_distance_m: Math.round(s.originDistM ?? 0),
      origin_eta_min: originEtaMin,
      route_distance_m: Math.round(s.routeDistM),
      status_message: makeMessage(s),
      limitYn: s.limitYn,
      limitDetail: s.limitDetail,
      note: s.note,
      grouped_count: s.grouped_count ?? null,
      grouped_stations: Array.isArray(s.grouped_stations)
        ? s.grouped_stations.map(gs => ({
            statId: gs.statId,
            name: gs.name,
            operator: gs.operator,
            lat: gs.lat,
            lng: gs.lng,
            available_count: gs.avail,
            total_count: gs.total,
            unit_price: gs.unitPrice,
            address: gs.addr,
          }))
        : null,
      recommendation_label: s.recommendation_label ?? null,
      p_success: s.pSuccess != null ? Math.round(s.pSuccess * 100) : null,
    };
  };

  const recommendedFormatted = format(diverse[0]);

  // 10. AI 추천 메시지 생성
  const uiMessage = await generateEvUiMessage({
    batteryPercent,
    reachableKm,
    recommended: diverse[0],
    totalCandidates: candidates.length,
  });

  return {
    reachable_distance_km: Math.round(reachableKm * 10) / 10,
    charger_type: chargerType,
    recommended: { ...recommendedFormatted, ui_message: uiMessage },
    alternatives: diverse.slice(1).map(format),
    filtered_out_count: filteredOutCount,
    total_candidates: candidates.length,
  };
}

module.exports = { evAiRecommend };
