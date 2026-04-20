const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { getNotifications, markAllRead } = require('../controllers/notificationController');

router.get('/', auth, getNotifications);
router.put('/read-all', auth, markAllRead);

module.exports = router;