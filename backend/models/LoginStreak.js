const mongoose = require('mongoose');

const loginStreakSchema = new mongoose.Schema({
  userId: {
    type: String,
    ref: 'User',
    required: true,
    unique: true,
    index: true,
  },
  currentStreak: {
    type: Number,
    default: 0,
  },
  lastLoginDate: {
    type: Date,
    default: Date.now,
  },
  longestStreak: {
    type: Number,
    default: 0,
  },
}, { timestamps: true });

module.exports = mongoose.model('LoginStreak', loginStreakSchema);
