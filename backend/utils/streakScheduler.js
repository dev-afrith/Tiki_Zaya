const cron = require('node-cron');
const InteractionStreak = require('../models/InteractionStreak');
const User = require('../models/User');
const { createAndEmitNotification } = require('./notifications');

/**
 * Initializes the streak scheduler.
 * Runs every hour.
 */
exports.initStreakScheduler = (io) => {
  // Check every hour at minute 0
  cron.schedule('0 * * * *', async () => {
    console.log('⏰ Running streak expiration check...');
    await processInteractionStreaks(io);
  });
};

async function processInteractionStreaks(io) {
  const now = new Date();
  const warningThreshold = 22 * 60 * 60 * 1000; // 22 hours
  const expiryThreshold = 30 * 60 * 60 * 1000; // 30 hours (24h + 6h grace)

  try {
    const activeStreaks = await InteractionStreak.find({ status: 'active', streakCount: { $gt: 0 } });

    for (const streak of activeStreaks) {
      const lastInt = new Date(streak.lastInteractionTime);
      const elapsed = now - lastInt;

      if (elapsed > expiryThreshold) {
        // BREAK STREAK
        streak.status = 'broken';
        // We don't reset count immediately so we can show "Streak broken" UI if needed,
        // but for this app logic, let's reset it.
        streak.streakCount = 0;
        await streak.save();
        console.log(`💀 Streak broken between ${streak.user1} and ${streak.user2}`);
      } else if (elapsed > warningThreshold && !streak.warningSent) {
        // SEND WARNING
        const hoursLeft = Math.ceil((expiryThreshold - elapsed) / (1000 * 60 * 60));
        
        await sendWarning(io, streak.user1, streak.user2, hoursLeft);
        await sendWarning(io, streak.user2, streak.user1, hoursLeft);
        
        streak.warningSent = true;
        await streak.save();
        console.log(`⚠️ Streak warning sent for ${streak.user1} and ${streak.user2}`);
      }
    }
  } catch (error) {
    console.error('Streak Scheduler Error:', error);
  }
}

async function sendWarning(io, userId, peerId, hoursLeft) {
  const peer = await User.findById(peerId).select('username');
  if (!peer) return;

  await createAndEmitNotification(io, {
    userId,
    actorUserId: peerId,
    type: 'streak_warning', // Custom type for deep linking
    title: '🔥 Streak ending soon!',
    body: `Your streak with ${peer.username} ends in ${hoursLeft} hours. Send a message to keep it alive!`,
    entityType: 'interaction_streak',
  });
}
