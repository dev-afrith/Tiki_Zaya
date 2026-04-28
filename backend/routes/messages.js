const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const os = require('os');
const auth = require('../middleware/auth');
const {
  getInbox,
  getConversation,
  sendMessage,
  getUnreadCount,
  markConversationRead,
  acknowledgeReelWatch,
  reactToMessage,
} = require('../controllers/messageController');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, os.tmpdir()),
  filename: (req, file, cb) => cb(null, `chat_${Date.now()}${path.extname(file.originalname)}`),
});

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('audio/')) {
    cb(null, true);
  } else {
    cb(new Error('Only image/audio files are allowed'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 },
});

router.get('/inbox', auth, getInbox);
router.get('/unread-count', auth, getUnreadCount);
router.get('/:userId', auth, getConversation);
router.post('/:userId', auth, upload.single('image'), sendMessage);
router.put('/read/:userId', auth, markConversationRead);
router.post('/reel/acknowledge', auth, acknowledgeReelWatch);
router.post('/react/:messageId', auth, reactToMessage);

module.exports = router;
