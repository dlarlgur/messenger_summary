const express = require('express');
const router = express.Router();
const axios = require('axios');
const { getCache, setCache } = require('../middleware/cache');

const OCM_BASE = 'https://api.openchargemap.io/v3/poi';
// Tesla 관련 커넥터 타입 ID (OCM 기준)
// 27: Tesla (Type 2 Supercharger), 30: Tesla Supercharger DC, 32: Tesla (Roadster)
const TESLA_CONNECTION_TYPES = '27,30,32,33';

/**
 * GET /api/stations/tesla/around
 * OCM으로 주변 Tesla 충전소 조회
 * Query: lat, lng, radius(m)
 */
router.get('/around', async (req, res) => {
  try {
    const { lat, lng, radius = 5000 } = req.query;
    if (!lat || !lng) return res.status(400).json({ error: 'lat, lng 필수' });

    const distKm = Math.ceil(parseInt(radius) / 1000);
    const cacheKey = `tesla:around:${parseFloat(lat).toFixed(3)}:${parseFloat(lng).toFixed(3)}:${distKm}`;
    const cached = await getCache(cacheKey);
    if (cached) return res.json({ data: cached, count: cached.length, cached: true });

    const response = await axios.get(OCM_BASE, {
      params: {
        output: 'json',
        latitude: lat,
        longitude: lng,
        distance: distKm,
        distanceunit: 'KM',
        countrycode: 'KR',
        connectiontypeid: TESLA_CONNECTION_TYPES,
        maxresults: 100,
        compact: true,
        verbose: false,
        key: process.env.OCM_API_KEY,
      },
      timeout: 10000,
    });

    const raw = response.data || [];
    const result = raw.map(poi => _mapPoi(poi)).filter(Boolean);

    // 30분 캐시 (테슬라 데이터는 자주 안바뀜)
    await setCache(cacheKey, result, 1800);

    res.json({ data: result, count: result.length });
  } catch (err) {
    console.error('[TESLA /around]', err.message);
    res.status(500).json({ error: '테슬라 충전소 조회 실패' });
  }
});

/**
 * GET /api/stations/tesla/:uuid
 * 상세 조회
 */
router.get('/:uuid', async (req, res) => {
  try {
    const cacheKey = `tesla:detail:${req.params.uuid}`;
    const cached = await getCache(cacheKey);
    if (cached) return res.json({ data: cached });

    const response = await axios.get(OCM_BASE, {
      params: {
        output: 'json',
        uuid: req.params.uuid,
        countrycode: 'KR',
        verbose: false,
        key: process.env.OCM_API_KEY,
      },
      timeout: 10000,
    });

    const raw = response.data?.[0];
    if (!raw) return res.status(404).json({ error: '충전소 없음' });

    const result = _mapPoi(raw);
    await setCache(cacheKey, result, 3600);
    res.json({ data: result });
  } catch (err) {
    console.error('[TESLA /:uuid]', err.message);
    res.status(500).json({ error: '테슬라 상세 조회 실패' });
  }
});

function _mapPoi(poi) {
  const addr = poi.AddressInfo;
  if (!addr?.Latitude || !addr?.Longitude) return null;

  const connections = poi.Connections || [];
  const isSupercharger = connections.some(c => [27, 30, 33].includes(c.ConnectionTypeID));

  const chargers = connections.map((c, i) => ({
    chgerId: `${poi.UUID}-${i}`,
    chgerType: isSupercharger ? 'SC' : 'DT',  // SC: 슈퍼차저, DT: 데스티네이션
    output: c.PowerKW ? Math.round(c.PowerKW) : (isSupercharger ? 150 : 11),
    stat: 0,  // 실시간 상태 미지원
    quantity: c.Quantity || 1,
  }));

  const totalCount = connections.reduce((sum, c) => sum + (c.Quantity || 1), 0);
  const operatorName = poi.OperatorInfo?.Title || 'Tesla';
  const stationType = isSupercharger ? '슈퍼차저' : '데스티네이션';

  // 한국어 이름 구성: 위치 정보에서 의미 있는 부분 추출
  const location = addr.Town || addr.StateOrProvince || '';
  const korName = location || addr.Title || stationType;

  return {
    statId: poi.UUID,
    name: korName,
    address: [addr.AddressLine1, addr.Town, addr.StateOrProvince].filter(Boolean).join(' '),
    lat: addr.Latitude,
    lng: addr.Longitude,
    operator: operatorName,
    phone: addr.ContactTelephone1 || null,
    useTime: '24시간',
    parkingFree: false,
    distance: addr.Distance ? Math.round(addr.Distance * 1000) : null,
    kind: null,
    stationType,           // 'SC' or 'DT' 구분용
    isTesla: true,
    chargers,
    totalCount,
    availableCount: 0,  // 실시간 데이터 없음 (isTesla로 구분)
    chargingCount: 0,
    unitPriceFast: null,
    unitPriceSlow: null,
    unitPriceFastMember: null,
    unitPriceSlowMember: null,
    numPoints: poi.NumberOfPoints || totalCount,
  };
}

module.exports = router;
