const { pool } = require('../db');
const opinet = require('./opinet');

let admin = null;
function getAdmin() {
  if (admin) return admin;
  try {
    admin = require('firebase-admin');
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!serviceAccount) {
      console.warn('[ALERT] FIREBASE_SERVICE_ACCOUNT_PATH 미설정 → FCM 비활성');
      return null;
    }
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccount)),
      });
    }
    return admin;
  } catch (e) {
    console.warn('[ALERT] firebase-admin 초기화 실패:', e.message);
    return null;
  }
}

const APP_ID = 'com.dksw.charge';

function kstDateStr() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10);
}

function kstNow() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return { hour: kst.getUTCHours(), minute: kst.getUTCMinutes() };
}

function fuelTypeLabel(code) {
  const map = { B027: '휘발유', B034: '고급휘발유', D047: '경유', K015: 'LPG' };
  return map[code] || code;
}

/** 동시 실행 수를 제한하는 병렬 처리 */
async function runConcurrent(items, limit, fn) {
  const results = [];
  let idx = 0;
  async function worker() {
    while (idx < items.length) {
      const i = idx++;
      try { results[i] = await fn(items[i], i); }
      catch (e) { results[i] = null; }
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

/**
 * 1분마다 실행: KST 기준 현재 시각에 알림 설정한 기기에 발송
 */
async function runMinuteBatch() {
  const { hour, minute } = kstNow();
  const today = kstDateStr();
  const fb = getAdmin();

  try {
    // ── 1. 발송 대상 기기 + 구독 전체를 단일 쿼리로 조회 ──
    const [rows] = await pool.execute(
      `SELECT d.device_id, d.fcm_token,
              s.station_id, s.station_name, s.fuel_type, s.last_notified_price
       FROM push_devices d
       INNER JOIN gas_alert_subscriptions s
         ON s.app_id = d.app_id AND s.device_id = d.device_id
       WHERE d.app_id = ?
         AND d.alert_hour = ?
         AND d.alert_minute = ?
         AND NOT (
           d.last_alerted_date <=> ?
           AND d.last_alerted_hour <=> ?
           AND d.last_alerted_minute <=> ?
         )`,
      [APP_ID, hour, minute, today, hour, minute]
    );

    if (rows.length === 0) return;

    // ── 2. 기기별 구독 그룹핑 ──
    const deviceMap = new Map(); // deviceId → { fcmToken, subs[] }
    for (const row of rows) {
      if (!deviceMap.has(row.device_id)) {
        deviceMap.set(row.device_id, { fcmToken: row.fcm_token, subs: [] });
      }
      deviceMap.get(row.device_id).subs.push(row);
    }

    const deviceCount = deviceMap.size;
    console.log(`[ALERT] ${hour}:${String(minute).padStart(2,'0')} KST — ${deviceCount}개 기기 배치 시작`);

    // ── 3. 고유 주유소 목록 추출 → 가격 일괄 조회 (동시 10개) ──
    const stationIds = [...new Set(rows.map(r => r.station_id))];
    console.log(`[ALERT] 가격 조회 대상 주유소 ${stationIds.length}개 (기기 ${deviceCount}개)`);

    const priceMap = {}; // "stationId:fuelType" → price
    await runConcurrent(stationIds, 10, async (stationId) => {
      try {
        const detail = await opinet.getStationDetail(stationId);
        const oilPrices = detail?.base?.OIL_PRICE || [];
        for (const oil of oilPrices) {
          priceMap[`${stationId}:${oil.PRODCD}`] = parseFloat(oil.PRICE);
        }
      } catch (e) {
        console.error(`[ALERT] 가격 조회 실패: station=${stationId}`, e.message);
      }
    });

    console.log(`[ALERT] 가격 조회 완료 (${Object.keys(priceMap).length}개 유종)`);

    // ── 4. 기기별 FCM 발송 (동시 50개) ──
    const deviceEntries = [...deviceMap.entries()];
    let successCount = 0;
    let failCount = 0;

    await runConcurrent(deviceEntries, 50, async ([deviceId, { fcmToken, subs }]) => {
      // 구독 주유소별 가격 구성
      const stations = [];
      const updates = [];

      for (const sub of subs) {
        const fuelTypes = sub.fuel_type.split(',');
        const stationPrices = [];

        let lastPrices = {};
        try { if (sub.last_notified_price) lastPrices = JSON.parse(sub.last_notified_price); }
        catch { /* 구버전 무시 */ }

        const newPrices = {};
        for (const fuelType of fuelTypes) {
          const currentPrice = priceMap[`${sub.station_id}:${fuelType}`];
          if (currentPrice == null) continue;

          const rounded = Math.round(currentPrice);
          newPrices[fuelType] = rounded;
          const prev = lastPrices[fuelType];
          stationPrices.push({
            fuelType: fuelTypeLabel(fuelType),
            price: rounded,
            change: (prev != null) ? rounded - prev : 0,
          });
        }

        if (stationPrices.length > 0) {
          stations.push({ name: sub.station_name, prices: stationPrices });
          updates.push({ stationId: sub.station_id, prices: JSON.stringify(newPrices) });
        }
      }

      if (stations.length === 0) return;

      // FCM 발송
      if (fb && fcmToken) {
        try {
          await fb.messaging().send({
            token: fcmToken,
            data: {
              type: 'gas_price_alert',
              stations: JSON.stringify(stations),
            },
            android: { priority: 'high' },
          });
          successCount++;
        } catch (e) {
          failCount++;
          console.error(`[ALERT] FCM 실패 device=${deviceId.slice(0,8)}..`, e.code || e.message);
          if (e.code === 'messaging/registration-token-not-registered') {
            await pool.execute(
              `DELETE FROM push_devices WHERE app_id = ? AND device_id = ?`,
              [APP_ID, deviceId]
            ).catch(() => {});
          }
          return;
        }
      }

      // DB 업데이트 (발송 기록 + 가격 저장)
      await pool.execute(
        `UPDATE push_devices SET last_alerted_date=?, last_alerted_hour=?, last_alerted_minute=?
         WHERE app_id=? AND device_id=?`,
        [today, hour, minute, APP_ID, deviceId]
      ).catch(() => {});

      await Promise.all(updates.map(({ stationId, prices }) =>
        pool.execute(
          `UPDATE gas_alert_subscriptions SET last_notified_price=?, updated_at=NOW()
           WHERE app_id=? AND device_id=? AND station_id=?`,
          [prices, APP_ID, deviceId, stationId]
        ).catch(() => {})
      ));
    });

    console.log(`[ALERT] 배치 완료 — 성공 ${successCount}개 / 실패 ${failCount}개`);

  } catch (e) {
    console.error('[ALERT] runMinuteBatch 실패:', e.message || e);
    if (e.stack) console.error(e.stack);
  }
}

module.exports = { runMinuteBatch };
