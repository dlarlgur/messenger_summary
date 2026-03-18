const express = require('express');
const router = express.Router();
const { pool } = require('../db');

const APP_ID = 'com.dksw.charge';

/**
 * POST /api/alerts/device
 * FCM 토큰 등록/갱신
 */
router.post('/device', async (req, res) => {
  const { deviceId, fcmToken } = req.body;
  if (!deviceId || !fcmToken) return res.status(400).json({ error: 'deviceId, fcmToken 필수' });
  try {
    await pool.execute(
      `INSERT INTO push_devices (app_id, device_id, fcm_token)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE fcm_token = VALUES(fcm_token), updated_at = NOW()`,
      [APP_ID, deviceId, fcmToken]
    );
    res.json({ ok: true });
  } catch (e) {
    console.error('[ALERTS] device 등록 실패:', e.message);
    res.status(500).json({ error: '등록 실패' });
  }
});

/**
 * GET /api/alerts/subscriptions/:deviceId
 * 구독 목록 조회
 */
router.get('/subscriptions/:deviceId', async (req, res) => {
  const { deviceId } = req.params;
  try {
    const [rows] = await pool.execute(
      `SELECT station_id, station_name, fuel_type
       FROM gas_alert_subscriptions
       WHERE app_id = ? AND device_id = ?
       ORDER BY created_at DESC`,
      [APP_ID, deviceId]
    );
    res.json({ data: rows });
  } catch (e) {
    res.status(500).json({ error: '조회 실패' });
  }
});

/**
 * POST /api/alerts/subscribe
 * 주유소 알림 구독 (여러 유종 한 번에)
 */
router.post('/subscribe', async (req, res) => {
  const { deviceId, stationId, stationName, fuelTypes = 'B027' } = req.body;
  if (!deviceId || !stationId) return res.status(400).json({ error: 'deviceId, stationId 필수' });

  try {
    // 주유소 5개 제한 체크 (신규 주유소인 경우)
    const [[{ already }]] = await pool.execute(
      `SELECT COUNT(*) AS already FROM gas_alert_subscriptions
       WHERE app_id = ? AND device_id = ? AND station_id = ?`,
      [APP_ID, deviceId, stationId]
    );
    if (!already) {
      const [[{ cnt }]] = await pool.execute(
        `SELECT COUNT(DISTINCT station_id) AS cnt FROM gas_alert_subscriptions 
         WHERE app_id = ? AND device_id = ?`,
        [APP_ID, deviceId]
      );
      if (cnt >= 3) return res.status(400).json({ error: '알림은 최대 3개 주유소까지 설정 가능합니다', code: 'LIMIT_EXCEEDED' });
    }

    // 기존 구독 삭제 후 새로 추가 (유종 변경 반영)
    await pool.execute(
      `DELETE FROM gas_alert_subscriptions 
       WHERE app_id = ? AND device_id = ? AND station_id = ?`,
      [APP_ID, deviceId, stationId]
    );

    // fuelTypes를 쉼표로 구분해서 저장 (단일 행)
    await pool.execute(
      `INSERT INTO gas_alert_subscriptions (app_id, device_id, station_id, station_name, fuel_type)
       VALUES (?, ?, ?, ?, ?)`,
      [APP_ID, deviceId, stationId, stationName ?? '', fuelTypes]
    );
    
    res.json({ ok: true });
  } catch (e) {
    console.error('[ALERTS] subscribe 실패:', e.message);
    res.status(500).json({ error: '구독 실패' });
  }
});

/**
 * DELETE /api/alerts/unsubscribe
 * 주유소 알림 해제 (전체)
 */
router.delete('/unsubscribe', async (req, res) => {
  const { deviceId, stationId } = req.body;
  if (!deviceId || !stationId) return res.status(400).json({ error: 'deviceId, stationId 필수' });
  try {
    await pool.execute(
      `DELETE FROM gas_alert_subscriptions 
       WHERE app_id = ? AND device_id = ? AND station_id = ?`,
      [APP_ID, deviceId, stationId]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: '해제 실패' });
  }
});

/**
 * PUT /api/alerts/time
 * 기기별 알림 시각 설정
 */
router.put('/time', async (req, res) => {
  const { deviceId, hour, minute } = req.body;
  if (!deviceId || hour === undefined || minute === undefined) {
    return res.status(400).json({ error: 'deviceId, hour, minute 필수' });
  }
  const h = parseInt(hour);
  const m = parseInt(minute);
  if (isNaN(h) || isNaN(m) || h < 0 || h > 23 || m < 0 || m > 59) {
    return res.status(400).json({ error: 'hour(0~23), minute(0~59) 범위 초과' });
  }
  try {
    await pool.execute(
      `UPDATE push_devices SET alert_hour = ?, alert_minute = ? WHERE app_id = ? AND device_id = ?`,
      [h, m, APP_ID, deviceId]
    );
    res.json({ ok: true });
  } catch (e) {
    console.error('[ALERTS] time 설정 실패:', e.message);
    res.status(500).json({ error: '설정 실패' });
  }
});

module.exports = router;
