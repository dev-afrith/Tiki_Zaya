const crypto = require('crypto');
const User = require('../models/User');
const {
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
  verifyPassword,
  verifyRefreshJwt,
} = require('../utils/authSecurity');

const publicUser = (user) => {
  const data = user.toJSON ? user.toJSON() : { ...user };
  data.id = data._id;
  return data;
};

const duplicateMessage = (error) => {
  if (error?.code !== 11000) return '';
  const key = Object.keys(error.keyPattern || error.keyValue || {})[0];
  if (key === 'username') return 'Username is already taken';
  if (key === 'phone') return 'Phone number is already registered';
  if (key === 'email') return 'Email is already registered';
  return 'Account already exists';
};

const cleanExpiredRefreshTokens = (user) => {
  const now = new Date();
  user.refreshTokens = (user.refreshTokens || []).filter((session) => session.expiresAt > now);
};

const issueSession = async (user, req) => {
  cleanExpiredRefreshTokens(user);
  const accessToken = signAccessToken(user);
  const refreshToken = signRefreshToken(user);
  user.refreshTokens.push({
    tokenHash: hashToken(refreshToken),
    device: req.get('user-agent') || '',
    ip: req.ip || '',
    expiresAt: getRefreshExpiry(),
  });
  user.refreshTokens = user.refreshTokens.slice(-5);
  await user.save();
  return { accessToken, refreshToken };
};

exports.register = async (req, res) => {
  try {
    const username = normalizeUsername(req.body.username);
    const email = normalizeEmail(req.body.email);
    const phone = normalizePhone(req.body.phone);
    const password = (req.body.password || '').toString();
    const name = (req.body.name || username).toString().trim();
    const dobResult = parseValidDob(req.body.dateOfBirth || req.body.dob);

    if (!isValidUsername(username)) {
      return res.status(400).json({ message: 'Username must be 3-30 characters and use only lowercase letters, numbers, and underscores' });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ message: 'Please enter a valid email address' });
    }
    if (!phone) {
      return res.status(400).json({ message: 'Please enter a valid phone number' });
    }
    const passwordError = validatePassword(password);
    if (passwordError) {
      return res.status(400).json({ message: passwordError });
    }
    if (dobResult.error) {
      return res.status(400).json({ message: dobResult.error });
    }

    const existing = await User.findOne({
      $or: [{ username }, { email }],
    }).select('username email');
    if (existing) {
      if (existing.username === username) return res.status(409).json({ message: 'Username is already taken' });
      if (existing.email === email) return res.status(409).json({ message: 'Email is already registered' });
    }

    const user = new User({
      _id: crypto.randomUUID(),
      username,
      email,
      phone,
      passwordHash: await hashPassword(password),
      passwordUpdatedAt: new Date(),
      dateOfBirth: dobResult.date,
      name: name.slice(0, 60),
      role: 'user',
      status: 'active',
    });

    const session = await issueSession(user, req);
    return res.status(201).json({
      token: session.accessToken,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: publicUser(user),
    });
  } catch (error) {
    const message = duplicateMessage(error);
    if (message) return res.status(409).json({ message });
    return res.status(500).json({ error: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    const identifier = detectLoginIdentifier(req.body.identifier || req.body.login || req.body.email || '');
    const password = (req.body.password || '').toString();
    if (!identifier.value || !password) {
      return res.status(400).json({ message: 'Username or phone number and password are required' });
    }

    const user = await User.findOne({ [identifier.type]: identifier.value }).select('+passwordHash +refreshTokens +refreshTokens.tokenHash');
    if (!user || !user.passwordHash) {
      return res.status(401).json({ message: 'Invalid username/phone or password' });
    }

    const ok = await verifyPassword(password, user.passwordHash);
    if (!ok) {
      return res.status(401).json({ message: 'Invalid username/phone or password' });
    }
    if (user.status === 'blocked') {
      return res.status(403).json({ message: 'Your account is blocked. Contact support.' });
    }

    const session = await issueSession(user, req);
    
    // Update login streak
    await require('../services/streakService').updateLoginStreak(user._id);

    return res.status(200).json({
      token: session.accessToken,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: publicUser(user),
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.refresh = async (req, res) => {
  try {
    const refreshToken = (req.body.refreshToken || '').toString();
    if (!refreshToken) return res.status(400).json({ message: 'Refresh token is required' });

    const decoded = verifyRefreshJwt(refreshToken);
    const user = await User.findById(decoded.uid || decoded.sub).select('+refreshTokens +refreshTokens.tokenHash');
    if (!user) return res.status(401).json({ message: 'Invalid refresh token' });

    const incomingHash = hashToken(refreshToken);
    const session = (user.refreshTokens || []).find((item) => item.tokenHash === incomingHash && item.expiresAt > new Date());
    if (!session) return res.status(401).json({ message: 'Invalid refresh token' });

    user.refreshTokens = user.refreshTokens.filter((item) => item.tokenHash !== incomingHash);
    const next = await issueSession(user, req);
    return res.status(200).json({
      token: next.accessToken,
      accessToken: next.accessToken,
      refreshToken: next.refreshToken,
      user: publicUser(user),
    });
  } catch (_) {
    return res.status(401).json({ message: 'Invalid or expired refresh token' });
  }
};

exports.logout = async (req, res) => {
  try {
    const refreshToken = (req.body.refreshToken || '').toString();
    if (refreshToken) {
      const user = await User.findById(req.userId).select('+refreshTokens +refreshTokens.tokenHash');
      if (user) {
        const tokenHash = hashToken(refreshToken);
        user.refreshTokens = (user.refreshTokens || []).filter((item) => item.tokenHash !== tokenHash);
        await user.save();
      }
    }
    return res.status(200).json({ ok: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.me = async (req, res) => {
  return res.status(200).json({ user: publicUser(req.user) });
};

exports.changePassword = async (req, res) => {
  try {
    const currentPassword = (req.body.oldPassword || req.body.currentPassword || '').toString();
    const newPassword = (req.body.newPassword || '').toString();
    const passwordError = validatePassword(newPassword);
    if (passwordError) return res.status(400).json({ message: passwordError });

    const user = await User.findById(req.userId).select('+passwordHash +refreshTokens +refreshTokens.tokenHash');
    if (!user || !user.passwordHash) {
      return res.status(400).json({ message: 'Password login is not enabled for this account' });
    }

    const ok = await verifyPassword(currentPassword, user.passwordHash);
    if (!ok) return res.status(401).json({ message: 'Current password is incorrect' });

    user.passwordHash = await hashPassword(newPassword);
    user.passwordUpdatedAt = new Date();
    user.refreshTokens = [];
    await user.save();
    return res.status(200).json({ message: 'Password changed. Please log in again.' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.forgotPassword = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    if (!isValidEmail(email)) return res.status(400).json({ message: 'Please enter a valid email address' });

    const user = await User.findOne({ email }).select('+passwordReset.otpHash');
    if (user) {
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      user.passwordReset = {
        otpHash: hashToken(otp),
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      };
      await user.save();
      console.log(`[AUTH] Password reset OTP for ${email}: ${otp}`);
    }

    return res.status(200).json({ message: 'If the email exists, a reset code has been sent' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.resetPassword = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const otp = (req.body.otp || '').toString();
    const newPassword = (req.body.newPassword || '').toString();
    const passwordError = validatePassword(newPassword);
    if (passwordError) return res.status(400).json({ message: passwordError });

    const user = await User.findOne({ email }).select('+passwordHash +refreshTokens +refreshTokens.tokenHash +passwordReset.otpHash');
    if (!user || !user.passwordReset?.otpHash || user.passwordReset.expiresAt < new Date()) {
      return res.status(400).json({ message: 'Invalid or expired reset code' });
    }
    if (user.passwordReset.otpHash !== hashToken(otp)) {
      return res.status(400).json({ message: 'Invalid or expired reset code' });
    }

    user.passwordHash = await hashPassword(newPassword);
    user.passwordUpdatedAt = new Date();
    user.passwordReset = { otpHash: '', expiresAt: null };
    user.refreshTokens = [];
    await user.save();
    return res.status(200).json({ message: 'Password reset successfully' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.verifyOtp = async (_req, res) => {
  return res.status(410).json({ message: 'Email OTP signup is no longer required. Please log in with username or phone.' });
};

exports.resendOtp = async (_req, res) => {
  return res.status(410).json({ message: 'Email OTP signup is no longer required.' });
};

exports.getAccountsByPhone = async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    if (!phone) {
      return res.status(400).json({ message: 'Valid 10-digit phone number strictly required' });
    }
    const accounts = await User.find({ phone }).select('_id username name');
    const result = accounts.map(acc => ({
      id: acc._id,
      username: acc.username,
      displayName: acc.name
    }));
    return res.status(200).json(result);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
