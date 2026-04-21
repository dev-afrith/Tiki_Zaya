const buckets = new Map();

const rateLimit = ({ windowMs = 15 * 60 * 1000, max = 20, keyPrefix = 'global' } = {}) => {
  return (req, res, next) => {
    const ip = req.ip || req.connection?.remoteAddress || 'unknown';
    const key = `${keyPrefix}:${ip}:${(req.body?.identifier || req.body?.username || req.body?.email || '').toString().toLowerCase()}`;
    const now = Date.now();
    const bucket = buckets.get(key) || { count: 0, resetAt: now + windowMs };

    if (bucket.resetAt <= now) {
      bucket.count = 0;
      bucket.resetAt = now + windowMs;
    }

    bucket.count += 1;
    buckets.set(key, bucket);

    if (bucket.count > max) {
      return res.status(429).json({ message: 'Too many attempts. Please try again later.' });
    }

    next();
  };
};

setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of buckets.entries()) {
    if (bucket.resetAt <= now) buckets.delete(key);
  }
}, 10 * 60 * 1000).unref();

module.exports = rateLimit;
