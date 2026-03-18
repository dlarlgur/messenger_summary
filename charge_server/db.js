const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  timezone: '+09:00',
});

async function initAlertTables() {
  const conn = await pool.getConnection();
  try {
    // 앱별 디바이스 FCM 토큰 (app_id = 패키지명)
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS push_devices (
        id          INT AUTO_INCREMENT PRIMARY KEY,
        app_id      VARCHAR(100) NOT NULL COMMENT '앱 패키지명 (com.dksw.charge 등)',
        device_id   VARCHAR(255) NOT NULL COMMENT '디바이스 고유 ID',
        fcm_token   TEXT         NOT NULL COMMENT 'FCM 푸시 토큰',
        created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        updated_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_app_device (app_id, device_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // 주유소 가격 알림 구독 (주유소당 여러 유종 쉼표 구분)
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS gas_alert_subscriptions (
        id                   INT AUTO_INCREMENT PRIMARY KEY,
        app_id               VARCHAR(100) NOT NULL,
        device_id            VARCHAR(255) NOT NULL,
        station_id           VARCHAR(50)  NOT NULL,
        station_name         VARCHAR(255),
        fuel_type            TEXT         NOT NULL COMMENT '쉼표 구분 유종 (예: B027,D047,K015)',
        last_notified_price  TEXT         COMMENT '유종별 이전 가격 JSON (예: {"B027":1500,"D047":1400})',
        created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_sub (app_id, device_id, station_id),
        KEY idx_app_station (app_id, station_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // last_notified_price 컬럼을 TEXT로 변경 (유종별 가격 JSON 저장)
    const [[{ db: dbName }]] = await conn.execute('SELECT DATABASE() AS db');
    const [priceCol] = await conn.execute(
      `SELECT DATA_TYPE FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'gas_alert_subscriptions' AND COLUMN_NAME = 'last_notified_price'`,
      [dbName]
    );
    if (priceCol.length > 0 && priceCol[0].DATA_TYPE !== 'text') {
      await conn.execute(`ALTER TABLE gas_alert_subscriptions MODIFY COLUMN last_notified_price TEXT COMMENT '유종별 이전 가격 JSON (예: {"B027":1500,"D047":1400})'`);
      console.log('[DB] gas_alert_subscriptions.last_notified_price → TEXT로 변경 완료');
    }

    // alert_hour, alert_minute, last_alerted_date 컬럼 추가 (MySQL은 IF NOT EXISTS 미지원 → 수동 체크)
    const [cols] = await conn.execute(
      `SELECT COLUMN_NAME FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'push_devices'`,
      [dbName]
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));
    const toAdd = [
      ['alert_hour',          'TINYINT NOT NULL DEFAULT 8'],
      ['alert_minute',        'TINYINT NOT NULL DEFAULT 0'],
      ['last_alerted_date',   'DATE'],
      ['last_alerted_hour',   'TINYINT'],
      ['last_alerted_minute', 'TINYINT'],
    ];
    for (const [col, def] of toAdd) {
      if (!existing.has(col)) {
        await conn.execute(`ALTER TABLE push_devices ADD COLUMN ${col} ${def}`);
        console.log(`[DB] push_devices.${col} 컬럼 추가 완료`);
      }
    }

    console.log('[DB] push_devices, gas_alert_subscriptions 테이블 준비 완료');
  } finally {
    conn.release();
  }
}

module.exports = { pool, initAlertTables };
