const express = require('express');
const router = express.Router();
const opinet = require('../services/opinet');
const { wgs84ToKatec, katecToWgs84 } = require('../services/coordinate');
const { cacheMiddleware } = require('../middleware/cache');

/**
 * GET /api/stations/gas/around
 * 반경 내 주유소 검색
 * Query: lat, lng, radius, fuelType, sort
 */
router.get('/around', cacheMiddleware(300), async (req, res) => {
  try {
    const { lat, lng, radius = 5000, fuelType = 'B027', sort = 1 } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'lat, lng 필수' });
    }

    // WGS84 → KATEC 변환
    const katec = wgs84ToKatec(parseFloat(lat), parseFloat(lng));

    const stations = await opinet.getAroundStations({
      x: katec.x,
      y: katec.y,
      radius: parseInt(radius),
      prodcd: fuelType,
      sort: parseInt(sort),
    });

    // 응답에 WGS84 좌표 추가
    const result = stations.map(s => {
      const wgs = katecToWgs84(parseFloat(s.GIS_X_COOR), parseFloat(s.GIS_Y_COOR));
      return {
        id: s.UNI_ID,
        name: s.OS_NM,
        brand: s.POLL_DIV_CD,
        address: s.NEW_ADR || s.VAN_ADR,
        price: parseFloat(s.PRICE),
        distance: parseFloat(s.DISTANCE),
        lat: wgs.lat,
        lng: wgs.lng,
        phone: s.TEL,
        isSelf: s.SELF_DIV_CD === 'Y',
        hasCarWash: s.CAR_WASH_YN === 'Y',
        hasMaintenance: s.MAINT_YN === 'Y',
        fuelType: fuelType,
      };
    });

    res.json({ data: result, count: result.length });
  } catch (err) {
    console.error('[GAS /around] 에러:', err.message || err);
    if (err.stack) console.error(err.stack);
    res.status(500).json({ error: '주유소 검색 실패' });
  }
});

/**
 * GET /api/stations/gas/:id
 * 주유소 상세 정보
 */
router.get('/:id', cacheMiddleware(600), async (req, res) => {
  try {
    const result = await opinet.getStationDetail(req.params.id);
    if (!result) return res.status(404).json({ error: '주유소를 찾을 수 없습니다' });

    const detail = result.base;
    const wgs = katecToWgs84(parseFloat(detail.GIS_X_COOR), parseFloat(detail.GIS_Y_COOR));

    // 유종별 가격 맵 & 판매 유종 목록
    const prices = {};
    const oilPrices = detail.OIL_PRICE || [];
    for (const oil of oilPrices) {
      const code = oil.PRODCD;
      const price = parseFloat(oil.PRICE);
      if (code && price > 0) prices[code] = price;
    }
    const availableFuelTypes = Object.keys(prices);

    res.json({
      data: {
        id: detail.UNI_ID,
        name: detail.OS_NM,
        brand: detail.POLL_DIV_CD,
        address: detail.NEW_ADR || detail.VAN_ADR,
        phone: detail.TEL,
        openTime: detail.LPG_YN === 'Y' ? '06:00~24:00' : '24시간',
        lat: wgs.lat,
        lng: wgs.lng,
        price: parseFloat(detail.PRICE),
        isSelf: detail.SELF_DIV_CD === 'Y',
        hasCarWash: detail.CAR_WASH_YN === 'Y',
        hasMaintenance: detail.MAINT_YN === 'Y',
        prices,               // { B027: 1500, D047: 1400, ... }
        availableFuelTypes,   // ['B027', 'D047', ...]
      },
    });
  } catch (err) {
    console.error('[GAS /:id] 에러:', err.message || err);
    if (err.stack) console.error(err.stack);
    res.status(500).json({ error: '주유소 상세 조회 실패' });
  }
});

module.exports = router;
