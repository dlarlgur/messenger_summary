const express = require('express');
const router = express.Router();
const opinet = require('../services/opinet');
const { cacheMiddleware } = require('../middleware/cache');

/**
 * GET /api/prices/gas/average
 * 전국 평균 유가
 */
router.get('/gas/average', cacheMiddleware(1800), async (req, res) => {
  try {
    const prices = await opinet.getAvgAllPrice();

    const result = {};
    prices.forEach(p => {
      result[p.PRODCD] = {
        code: p.PRODCD,
        name: p.PRODNM,
        price: parseFloat(p.PRICE),
        diff: parseFloat(p.DIFF),
        date: p.TRADE_DT,
      };
    });

    res.json({ data: result });
  } catch (err) {
    console.error('[PRICES /gas/average]', err.message);
    res.status(500).json({ error: '평균 유가 조회 실패' });
  }
});

/**
 * GET /api/prices/gas/lowest
 * 지역 최저가 TOP 10
 * Query: fuelType, area
 */
router.get('/gas/lowest', cacheMiddleware(300), async (req, res) => {
  try {
    const { fuelType = 'B027', area } = req.query;
    const stations = await opinet.getLowTop10({ prodcd: fuelType, area });

    res.json({ data: stations, count: stations.length });
  } catch (err) {
    console.error('[PRICES /gas/lowest]', err.message);
    res.status(500).json({ error: '최저가 조회 실패' });
  }
});

module.exports = router;
