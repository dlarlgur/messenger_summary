const mysql = require('mysql2/promise');

let pool = null;

function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '3306'),
      user: process.env.DB_USER || 'aiuser',
      password: process.env.DB_PASSWORD || 'aiuser123',
      database: process.env.DB_NAME || 'aidb',
      waitForConnections: true,
      connectionLimit: 5,
      timezone: '+09:00',
    });
    console.log('[DB] MySQL 풀 생성');
  }
  return pool;
}

module.exports = { getPool };
