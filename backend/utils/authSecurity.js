const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const ACCESS_TOKEN_TTL = process.env.JWT_ACCESS_TTL || '15m';
const REFRESH_TOKEN_DAYS = Number(process.env.JWT_REFRESH_DAYS || 30);

const scrypt = (password, salt) => new Promise((resolve, reject) => {
  crypto.scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 }, (error, derivedKey) => {
    if (error) reject(error);
    else resolve(derivedKey);
  });
});

const getJwtSecret = () => {
  const secret = process.env.JWT_SECRET || process.env.JWT_KEY || process.env.SECRET_KEY;
  if (!secret) {
    throw new Error('JWT_SECRET is required');
  }
  return secret;
};

const getRefreshSecret = () => process.env.JWT_REFRESH_SECRET || getJwtSecret();

const normalizeUsername = (value) => (value || '').toString().trim().toLowerCase();

const normalizeEmail = (value) => (value || '').toString().trim().toLowerCase();

const normalizePhone = (value) => {
  const raw = (value || '').toString().trim();
  if (!raw) return '';
  const compact = raw.replace(/[\s().-]/g, '');
  if (!/^\d{10}$/.test(compact)) return '';
  return compact;
};

const isPhoneIdentifier = (value) => {
  const raw = (value || '').toString().trim();
  if (!raw) return false;
  return /^\d{10}$/.test(raw.replace(/[\s().-]/g, ''));
};

const detectLoginIdentifier = (value) => {
  if (isPhoneIdentifier(value)) {
    return { type: 'phone', value: normalizePhone(value) };
  }
  return { type: 'username', value: normalizeUsername(value) };
};

const isValidUsername = (value) => /^[a-z0-9_]{3,30}$/.test(value);

const isValidEmail = (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

const validatePassword = (password) => {
  if (typeof password !== 'string' || password.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return 'Password must include at least one letter and one number';
  }
  return '';
};

const calculateAge = (dateOfBirth, now = new Date()) => {
  const dob = new Date(dateOfBirth);
  let age = now.getFullYear() - dob.getFullYear();
  const monthDiff = now.getMonth() - dob.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dob.getDate())) {
    age -= 1;
  }
  return age;
};

const parseValidDob = (value) => {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) {
    return { error: 'Invalid date of birth' };
  }
  if (date > new Date()) {
    return { error: 'Date of birth cannot be in the future' };
  }
  if (calculateAge(date) < 13) {
    return { error: 'You must be at least 13 years old to use TikiZaya' };
  }
  return { date };
};

const hashPassword = async (password) => {
  const salt = crypto.randomBytes(16).toString('hex');
  const derivedKey = await scrypt(password, salt);
  return `scrypt$16384$8$1$${salt}$${derivedKey.toString('hex')}`;
};

const verifyPassword = async (password, storedHash) => {
  if (!password || !storedHash) return false;
  const [scheme, n, r, p, salt, key] = storedHash.split('$');
  if (scheme !== 'scrypt' || !salt || !key) return false;

  const derivedKey = await new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, 64, { N: Number(n), r: Number(r), p: Number(p) }, (error, value) => {
      if (error) reject(error);
      else resolve(value);
    });
  });
  const storedKey = Buffer.from(key, 'hex');
  return storedKey.length === derivedKey.length && crypto.timingSafeEqual(storedKey, derivedKey);
};

const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

const signAccessToken = (user) => jwt.sign(
  {
    uid: user._id,
    sub: user._id,
    username: user.username || '',
    email: user.email || '',
    phone: user.phone || '',
    tokenUse: 'access',
  },
  getJwtSecret(),
  { expiresIn: ACCESS_TOKEN_TTL }
);

const signRefreshToken = (user) => jwt.sign(
  {
    uid: user._id,
    sub: user._id,
    tokenUse: 'refresh',
    sessionId: crypto.randomUUID(),
  },
  getRefreshSecret(),
  { expiresIn: `${REFRESH_TOKEN_DAYS}d` }
);

const verifyAccessJwt = (token) => {
  const decoded = jwt.verify(token, getJwtSecret());
  if (decoded.tokenUse && decoded.tokenUse !== 'access') {
    throw new Error('Invalid token use');
  }
  return decoded;
};

const verifyRefreshJwt = (token) => {
  const decoded = jwt.verify(token, getRefreshSecret());
  if (decoded.tokenUse !== 'refresh') {
    throw new Error('Invalid refresh token');
  }
  return decoded;
};

const getRefreshExpiry = () => new Date(Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000);

module.exports = {
  ACCESS_TOKEN_TTL,
  REFRESH_TOKEN_DAYS,
  calculateAge,
  detectLoginIdentifier,
  getRefreshExpiry,
  hashPassword,
  hashToken,
  isValidEmail,
  isValidUsername,
  normalizeEmail,
  normalizePhone,
  normalizeUsername,
  parseValidDob,
  signAccessToken,
  signRefreshToken,
  validatePassword,
  verifyAccessJwt,
  verifyPassword,
  verifyRefreshJwt,
};
