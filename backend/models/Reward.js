const mongoose = require('mongoose');

const rewardSchema = new mongoose.Schema({
  userId: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  rewardType: {
    type: String,
    enum: ['login_streak', 'interaction_streak'],
    required: true,
  },
  value: {
    type: Number,
    required: true,
  },
  milestone: {
    type: Number, // e.g., Day 3, 7, 30
  },
  metadata: {
    targetUserId: { type: String, ref: 'User' }, // For interaction streaks
  },
}, { timestamps: true });

module.exports = mongoose.model('Reward', rewardSchema);
