const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
  getInbox,
  getConversation,
  sendMessage,
  getUnreadCount,
  markConversationRead,
} = require('../controllers/messageController');

router.get('/inbox', auth, getInbox);
router.get('/unread-count', auth, getUnreadCount);
router.get('/:userId', auth, getConversation);
router.post('/:userId', auth, sendMessage);
router.put('/read/:userId', auth, markConversationRead);

module.exports = router;
