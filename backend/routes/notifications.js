const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { getNotifications, markAllRead, getUnreadCount, markOneRead } = require('../controllers/notificationController');

router.get('/', auth, getNotifications);
router.get('/unread-count', auth, getUnreadCount);
router.post('/mark-read', auth, markAllRead);
router.post('/mark-one-read/:id', auth, markOneRead);

module.exports = router;