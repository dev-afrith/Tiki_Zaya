const express = require('express');
const auth = require('../middleware/auth');
const rateLimit = require('../middleware/rateLimit');
const {
  changePassword,
  forgotPassword,
  getAccountsByPhone,
  login,
  logout,
  me,
  refresh,
  register,
  resendOtp,
  resetPassword,
  verifyOtp,
} = require('../controllers/authController');

const router = express.Router();

router.post('/register', rateLimit({ keyPrefix: 'register', max: 8, windowMs: 60 * 60 * 1000 }), register);
router.post('/login', rateLimit({ keyPrefix: 'login', max: 10, windowMs: 15 * 60 * 1000 }), login);
router.post('/getAccountsByPhone', rateLimit({ keyPrefix: 'getacc', max: 20, windowMs: 15 * 60 * 1000 }), getAccountsByPhone);
router.post('/refresh', refresh);
router.post('/logout', auth, logout);
router.get('/me', auth, me);
router.put('/change-password', auth, changePassword);
router.post('/forgot-password', rateLimit({ keyPrefix: 'forgot-password', max: 5, windowMs: 60 * 60 * 1000 }), forgotPassword);
router.post('/reset-password', rateLimit({ keyPrefix: 'reset-password', max: 8, windowMs: 60 * 60 * 1000 }), resetPassword);

router.post('/verify', verifyOtp);
router.post('/resend', resendOtp);

module.exports = router;
