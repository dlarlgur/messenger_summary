const { createClient } = require('redis');

let redisClient = null;

async function connectRedis() {
  const url = process.env.REDIS_URL || 'redis://localhost:6379';
  const client = createClient({ url });
  client.on('error', () => {});
  await client.connect();
  redisClient = client;
  console.log(`[CACHE] Redis 연결됨: ${url}`);
}

connectRedis().catch((e) => {
  console.log(`[CACHE] Redis 연결 실패 (${e.message}) → 인메모리 캐시 사용`);
});

// 인메모리 폴백
const memCache = new Map();

function getMemCache(key) {
  const item = memCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) { memCache.delete(key); return null; }
  return item.data;
}

function setMemCache(key, data, ttl) {
  memCache.set(key, { data, expiry: Date.now() + ttl * 1000 });
  if (memCache.size > 1000) memCache.delete(memCache.keys().next().value);
}

async function getCache(key) {
  if (redisClient?.isReady) {
    const val = await redisClient.get(key);
    return val ? JSON.parse(val) : null;
  }
  return getMemCache(key);
}

async function setCache(key, data, ttl) {
  if (redisClient?.isReady) {
    await redisClient.set(key, JSON.stringify(data), { EX: ttl });
    return;
  }
  setMemCache(key, data, ttl);
}

// ─── Geo 인덱스 ───
async function geoAdd(key, members) {
  if (!redisClient?.isReady) return false;
  // members = [{ longitude, latitude, member }, ...]
  const CHUNK = 5000;
  for (let i = 0; i < members.length; i += CHUNK) {
    await redisClient.geoAdd(key, members.slice(i, i + CHUNK));
  }
  return true;
}

async function geoSearch(key, lng, lat, radiusM) {
  if (!redisClient?.isReady) return null;
  try {
    const count = Math.min(Math.max(Math.ceil(radiusM / 5), 1000), 20000);
    return await redisClient.geoSearch(
      key,
      { longitude: lng, latitude: lat },
      { radius: radiusM, unit: 'm' },
      { SORT: 'ASC', COUNT: count }
    );
  } catch (e) {
    console.error('[CACHE] geoSearch 실패:', e.message);
    return null;
  }
}

async function hSetBulk(key, obj) {
  if (!redisClient?.isReady) return;
  // obj = { field: value, ... }
  const entries = Object.entries(obj);
  const CHUNK = 2000;
  for (let i = 0; i < entries.length; i += CHUNK) {
    const chunk = Object.fromEntries(entries.slice(i, i + CHUNK));
    await redisClient.hSet(key, chunk);
  }
}

async function hmGet(key, fields) {
  if (!redisClient?.isReady) return fields.map(() => null);
  return await redisClient.hmGet(key, fields);
}

async function expire(key, seconds) {
  if (!redisClient?.isReady) return;
  await redisClient.expire(key, seconds);
}

async function del(key) {
  if (!redisClient?.isReady) return;
  await redisClient.del(key);
}

async function rename(src, dst) {
  if (!redisClient?.isReady) return;
  await redisClient.rename(src, dst);
}

async function keyExists(key) {
  if (!redisClient?.isReady) return false;
  return (await redisClient.exists(key)) > 0;
}

function cacheMiddleware(ttl) {
  return async (req, res, next) => {
    const key = `charge:${req.originalUrl}`;
    const cached = await getCache(key);

    if (cached) {
      console.log(`[CACHE HIT] ${key}`);
      return res.json(cached);
    }

    const originalJson = res.json.bind(res);
    res.json = (body) => {
      if (res.statusCode === 200) setCache(key, body, ttl);
      return originalJson(body);
    };

    next();
  };
}

module.exports = { cacheMiddleware, getCache, setCache, geoAdd, geoSearch, hSetBulk, hmGet, expire, del, rename, keyExists };
