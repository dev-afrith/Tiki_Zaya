const mongoose = require('mongoose');

const interactionStreakSchema = new mongoose.Schema({
  user1: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  user2: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  streakCount: {
    type: Number,
    default: 0,
  },
  lastInteractionTime: {
    type: Date,
    default: Date.now,
  },
  lastInteractionUserId: {
    type: String,
    ref: 'User',
  },
  status: {
    type: String,
    enum: ['active', 'broken'],
    default: 'active',
  },
  warningSent: {
    type: Boolean,
    default: false,
  },
}, { timestamps: true });

// Ensure unique combination of users
interactionStreakSchema.index({ user1: 1, user2: 1 }, { unique: true });

module.exports = mongoose.model('InteractionStreak', interactionStreakSchema);
