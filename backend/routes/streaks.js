const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const InteractionStreak = require('../models/InteractionStreak');
const LoginStreak = require('../models/LoginStreak');

// Get interaction streak with a specific user
router.get('/interaction/:otherUserId', auth, async (req, res) => {
  try {
    const currentUserId = req.userId;
    const otherUserId = req.params.otherUserId;
    const sorted = [currentUserId, otherUserId].sort();
    
    const streak = await InteractionStreak.findOne({ 
      user1: sorted[0], 
      user2: sorted[1],
      status: 'active'
    });
    
    return res.status(200).json({ streak: streak || { streakCount: 0 } });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// Get personal login streak
router.get('/login', auth, async (req, res) => {
  try {
    const streak = await LoginStreak.findOne({ userId: req.userId });
    return res.status(200).json({ streak: streak || { currentStreak: 0, longestStreak: 0 } });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

module.exports = router;
