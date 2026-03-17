const express = require('express');
const router = express.Router();
const evApi = require('../services/evApi');
const { cacheMiddleware } = require('../middleware/cache');

/**
 * GET /api/stations/ev/around
 * 반경 내 충전소 검색
 * Query: lat, lng, radius
 */
router.get('/around', async (req, res) => {
  try {
    const { lat, lng, radius = 3000 } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'lat, lng 필수' });
    }

    const stations = await evApi.getStationsAround({
      lat: parseFloat(lat),
      lng: parseFloat(lng),
      radius: parseInt(radius),
    });

    // GEOSEARCH 경로: 이미 그룹핑된 충전소 객체 반환
    // zcode fallback 경로: raw 충전기 레코드(건당 1행) 반환 → 그룹핑 필요
    const isGrouped = stations.length > 0 && Array.isArray(stations[0].chargers);

    let result;
    if (isGrouped) {
      result = stations.map(s => {
        const chargers = s.chargers;
        return {
          statId: s.statId,
          name: s.statNm,
          address: s.addr,
          lat: s.lat,
          lng: s.lng,
          operator: s.busiNm,
          phone: s.busiCall ?? null,
          useTime: s.useTime || '24시간',
          parkingFree: s.parkingFree,
          distance: s.distance,
          kind: s.kind,
          kindDetail: s.kindDetail,
          unitPrice: chargers.find(c => c.unitPrice)?.unitPrice ?? null,
          chargers,
          totalCount: chargers.length,
          availableCount: chargers.filter(c => c.stat === 2).length,
          chargingCount: chargers.filter(c => c.stat === 3).length,
        };
      });
    } else {
      const grouped = {};
      stations.forEach(s => {
        const key = s.statId;
        if (!grouped[key]) {
          grouped[key] = {
            statId: s.statId,
            name: s.statNm,
            address: s.addr,
            lat: parseFloat(s.lat),
            lng: parseFloat(s.lng),
            operator: s.busiNm,
            phone: s.busiCall ?? null,
            useTime: s.useTime || '24시간',
            parkingFree: s.parkingFree === 'Y',
            distance: s.distance,
            kind: s.kind,
            kindDetail: s.kindDetail,
            chargers: [],
          };
        }
        grouped[key].chargers.push({
          chgerId: s.chgerId,
          chgerType: s.chgerType,
          output: parseInt(s.output || '7'),
          stat: parseInt(s.stat || '9'),
          statUpdDt: s.statUpdDt,
          unitPrice: s.unitPrice ? parseInt(s.unitPrice) : null,
        });
        if (!grouped[key].unitPrice && s.unitPrice) {
          grouped[key].unitPrice = parseInt(s.unitPrice);
        }
      });
      result = Object.values(grouped).map(station => {
        const total = station.chargers.length;
        return { ...station, totalCount: total, availableCount: station.chargers.filter(c => c.stat === 2).length, chargingCount: station.chargers.filter(c => c.stat === 3).length };
      });
    }

    res.json({ data: result, count: result.length });
  } catch (err) {
    console.error('[EV /around]', err.message);
    res.status(500).json({ error: '충전소 검색 실패' });
  }
});

/**
 * GET /api/stations/ev/:id
 * 충전소 상세 (info + status 합친 데이터)
 */
router.get('/:id', cacheMiddleware(60), async (req, res) => {
  try {
    const detail = await evApi.getStationDetail(req.params.id);
    if (!detail) return res.status(404).json({ error: '충전소를 찾을 수 없습니다' });

    res.json({ data: detail });
  } catch (err) {
    console.error('[EV /:id]', err.message);
    res.status(500).json({ error: '충전소 상세 조회 실패' });
  }
});

module.exports = router;
