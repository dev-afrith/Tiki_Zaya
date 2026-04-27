const cron = require('node-cron');
const User = require('../models/User');
const { createSystemNotification } = require('../utils/notifications');

/**
 * Smart Gamification Notifications Engine
 * Runs periodically to check for users who need a nudge to keep their streak,
 * claim rewards, or finish tasks.
 */
const initSmartNotifications = (io) => {
  // Run every hour to check for conditions
  cron.schedule('0 * * * *', async () => {
    console.log('[CRON] Running Smart Notification Engine...');
    try {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);

      // Find active users with push tokens who haven't exceeded the daily limit (4 max)
      // and haven't received a push in the last 4 hours (cooldown)
      const cooldownThreshold = new Date(now.getTime() - (4 * 60 * 60 * 1000));
      
      const eligibleUsers = await User.find({
        status: 'active',
        fcmTokens: { $exists: true, $not: { $size: 0 } },
        $or: [
          { dailyNotificationCount: { $lt: 4 } },
          { dailyNotificationCount: { $exists: false } }
        ],
        $or: [
          { lastNotificationSentAt: { $lte: cooldownThreshold } },
          { lastNotificationSentAt: null },
          { lastNotificationSentAt: { $exists: false } }
        ]
      });

      for (const user of eligibleUsers) {
        // Reset daily limit if a new day has started
        let currentDailyCount = user.dailyNotificationCount || 0;
        if (user.lastNotificationSentAt && user.lastNotificationSentAt < today) {
          currentDailyCount = 0;
        }

        let sentNotification = false;

        // 1. STREAK REMINDER
        // If they logged in yesterday but haven't logged in today
        const lastLogin = user.gamification.lastLoginAt;
        if (lastLogin && lastLogin >= yesterday && lastLogin < today) {
          // It's getting late (after 6 PM local time, using server time for now)
          if (now.getHours() >= 18) {
            await createSystemNotification(io, {
              userId: user._id,
              type: 'streak_reminder',
              body: `🔥 Don't miss your daily streak, @${user.username} — come back and keep it alive!`,
            });
            sentNotification = true;
          }
        }

        // 2. REWARD REMINDER
        // If they have completed tasks but haven't claimed rewards
        if (!sentNotification && user.gamification.completedTaskIds && user.gamification.claimedRewardIds) {
          if (user.gamification.completedTaskIds.length > user.gamification.claimedRewardIds.length) {
            await createSystemNotification(io, {
              userId: user._id,
              type: 'reward_available',
              body: `🎁 Mystery reward unlocked, @${user.username}! Claim your surprise reward before it disappears!`,
            });
            sentNotification = true;
          }
        }

        // 3. TASK PROGRESS
        // If they have watched some video but haven't finished tasks
        if (!sentNotification && user.gamification.watchRewardedMinutesToday > 0 && user.gamification.watchRewardedMinutesToday < 10) {
          await createSystemNotification(io, {
            userId: user._id,
            type: 'task_progress',
            body: `⏳ You're close, @${user.username}! Watch a few more minutes to complete your daily task!`,
          });
          sentNotification = true;
        }

        if (sentNotification) {
          user.lastNotificationSentAt = now;
          user.dailyNotificationCount = currentDailyCount + 1;
          await user.save();
        }
      }
    } catch (error) {
      console.error('[CRON] Error in Smart Notification Engine:', error);
    }
  });

  // Run at midnight to reset the daily limits
  cron.schedule('0 0 * * *', async () => {
    console.log('[CRON] Resetting daily notification limits...');
    try {
      await User.updateMany({}, { $set: { dailyNotificationCount: 0 } });
    } catch (error) {
      console.error('[CRON] Error resetting daily limits:', error);
    }
  });
};

module.exports = initSmartNotifications;
