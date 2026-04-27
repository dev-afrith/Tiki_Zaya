const Redis = require('ioredis');

let client = null;
let _ready = false;

/**
 * Initialize the Redis connection.
 * Uses Upstash Redis URL from REDIS_URL env variable.
 * Gracefully degrades — the app works without Redis, just slower.
 */
const init = () => {
  const url = process.env.REDIS_URL;
  if (!url) {
    console.warn('[REDIS] No REDIS_URL configured — caching disabled');
    return null;
  }

  try {
    client = new Redis(url, {
      maxRetriesPerRequest: 3,
      retryStrategy(times) {
        if (times > 5) return null; // Stop retrying after 5 attempts
        return Math.min(times * 200, 2000);
      },
      tls: url.startsWith('rediss://') ? {} : undefined,
      lazyConnect: false,
    });

    client.on('connect', () => {
      _ready = true;
      console.log('✅ Redis connected');
    });

    client.on('error', (err) => {
      console.error('[REDIS] Connection error:', err.message);
      _ready = false;
    });

    client.on('close', () => {
      _ready = false;
    });

    return client;
  } catch (err) {
    console.error('[REDIS] Failed to initialize:', err.message);
    return null;
  }
};

/**
 * Check if Redis is connected and ready.
 */
const isReady = () => _ready && client !== null;

/**
 * Get cached JSON value by key.
 * @returns {Object|null}
 */
const getJSON = async (key) => {
  if (!isReady()) return null;
  try {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    console.error('[REDIS GET]', err.message);
    return null;
  }
};

/**
 * Set JSON value with TTL in seconds.
 */
const setJSON = async (key, value, ttlSeconds = 90) => {
  if (!isReady()) return;
  try {
    await client.setex(key, ttlSeconds, JSON.stringify(value));
  } catch (err) {
    console.error('[REDIS SET]', err.message);
  }
};

/**
 * Delete a single key.
 */
const del = async (key) => {
  if (!isReady()) return;
  try {
    await client.del(key);
  } catch (err) {
    console.error('[REDIS DEL]', err.message);
  }
};

/**
 * Invalidate all feed-related cache keys.
 * Uses a SCAN-based approach to find keys by pattern.
 */
const invalidateFeedCache = async () => {
  if (!isReady()) return;
  try {
    const stream = client.scanStream({ match: 'feed:*', count: 100 });
    const pipeline = client.pipeline();
    let count = 0;

    for await (const keys of stream) {
      for (const key of keys) {
        pipeline.del(key);
        count++;
      }
    }

    // Also clear discovery cache
    pipeline.del('discovery');

    if (count > 0 || true) {
      await pipeline.exec();
    }
  } catch (err) {
    console.error('[REDIS INVALIDATE]', err.message);
  }
};

/**
 * Get the raw ioredis client (needed for BullMQ).
 */
const getClient = () => client;

/**
 * Graceful shutdown.
 */
const quit = async () => {
  if (client) {
    try {
      await client.quit();
    } catch (_) {}
    client = null;
    _ready = false;
  }
};

module.exports = {
  init,
  isReady,
  getJSON,
  setJSON,
  del,
  invalidateFeedCache,
  getClient,
  quit,
};
