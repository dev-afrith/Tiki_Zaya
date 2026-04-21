const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
  getMyGamification,
  claimReward,
  claimTask,
  getAppUpdate,
  getLeaderboard,
  recordWatchTime,
} = require('../controllers/gamificationController');

router.get('/me', auth, getMyGamification);
router.post('/tasks/:taskId/claim', auth, claimTask);
router.post('/rewards/:rewardId/claim', auth, claimReward);
router.post('/watch', auth, recordWatchTime);
router.get('/leaderboard', getLeaderboard);
router.get('/app-update', getAppUpdate);

module.exports = router;
