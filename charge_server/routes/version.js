const express = require('express');
const router = express.Router();
const { getPool } = require('../middleware/db');

/**
 * GET /api/version?app=charge&platform=ANDROID
 * 앱 버전 정보 조회
 */
router.get('/', async (req, res) => {
  const { app, platform } = req.query;

  if (!app || !platform) {
    return res.status(400).json({ error: 'app, platform 파라미터 필수' });
  }

  try {
    const pool = getPool();
    const [rows] = await pool.query(
      `SELECT latest_version, latest_version_code, min_version, min_version_code,
              release_note, force_update
       FROM app_versions
       WHERE app_name = ? AND platform = ? AND is_active = 1
       LIMIT 1`,
      [app, platform.toUpperCase()]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: '버전 정보 없음' });
    }

    res.json({ data: rows[0] });
  } catch (err) {
    console.error('[VERSION]', err.message);
    res.status(500).json({ error: '버전 조회 실패' });
  }
});

module.exports = router;
