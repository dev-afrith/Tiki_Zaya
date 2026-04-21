const admin = require('firebase-admin');
const path = require('path');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Initialize Firebase Admin
try {
  const serviceAccount = require(path.join(__dirname, '../config/firebase-service-account.json'));
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase Admin Initialized');
  }
} catch (error) {
  console.error('⚠️ Firebase Admin failed to initialize. Ensure service account key exists at backend/config/firebase-service-account.json');
}

const verifyToken = async (idToken) => {
  return await admin.auth().verifyIdToken(idToken);
};

const verifyLegacyToken = (token) => {
  const secret = process.env.JWT_SECRET || process.env.JWT_KEY || process.env.SECRET_KEY;
  if (!secret) return null;

  try {
    return jwt.verify(token, secret);
  } catch (_) {
    return null;
  }
};

const getLegacyUserId = (decoded) => {
  if (!decoded) return '';
  return (decoded.uid || decoded.userId || decoded.id || decoded._id || decoded.sub || '').toString();
};

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No authentication token provided' });
    }

    const idToken = authHeader.split('Bearer ')[1];

    let uid = '';
    let decodedEmail = '';
    let decodedPhone = '';
    let authProvider = '';

    try {
      // Verify the Firebase ID Token
      const decodedToken = await verifyToken(idToken);
      uid = decodedToken.uid;
      decodedEmail = decodedToken.email || '';
      decodedPhone = decodedToken.phone_number || '';
      authProvider = decodedToken.firebase?.sign_in_provider || '';
    } catch (firebaseError) {
      const legacyToken = verifyLegacyToken(idToken);
      uid = getLegacyUserId(legacyToken);
      decodedEmail = legacyToken?.email || '';
      decodedPhone = legacyToken?.phone || legacyToken?.phone_number || '';
      authProvider = uid ? 'legacy_jwt' : '';

      if (!uid) {
        console.error('Firebase Auth Error:', firebaseError.message);
        return res.status(401).json({ message: 'Invalid or expired authentication token' });
      }
    }

    let user = await User.findById(uid);
    if (!user) {
      console.log(`[AUTH] Creating new user document for UID: ${uid}`);
      user = new User({
        _id: uid,
        email: decodedEmail,
        phone: decodedPhone,
        role: 'user',
        status: 'active',
        username: null, // Onboarding will fill this later
      });
      await user.save();
    } else {
      const nextEmail = decodedEmail || user.email || '';
      const nextPhone = decodedPhone || user.phone || '';

      let changed = false;
      if (nextEmail && user.email !== nextEmail) {
        user.email = nextEmail;
        changed = true;
      }
      if (nextPhone && user.phone !== nextPhone) {
        user.phone = nextPhone;
        changed = true;
      }
      if (!user.role || user.role !== 'user') {
        user.role = 'user';
        changed = true;
      }
      if (!user.status) {
        user.status = 'active';
        changed = true;
      }
      if (changed) {
        await user.save();
      }
    }

    if (user.status === 'blocked') {
      return res.status(403).json({ message: 'Account is blocked' });
    }

    // Attach UID and user object to the request
    req.userId = uid;
    req.user = user;
    req.authIdentity = {
      email: decodedEmail,
      phone: decodedPhone,
      provider: authProvider,
    };
    
    next();
  } catch (error) {
    console.error('Firebase Auth Error:', error.message);
    res.status(401).json({ message: 'Invalid or expired authentication token' });
  }
};

module.exports = authMiddleware;
module.exports.verifyToken = verifyToken;
