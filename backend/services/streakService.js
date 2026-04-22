const InteractionStreak = require('../models/InteractionStreak');
const LoginStreak = require('../models/LoginStreak');
const Reward = require('../models/Reward');
const User = require('../models/User');
const { createAndEmitNotification } = require('../utils/notifications');

const STREAK_GRACE_HOURS = 30; // 24h + 6h grace

/**
 * Updates or starts the interaction streak between two users.
 * Triggered by a meaningful interaction (message, reel watch).
 */
exports.updateInteractionStreak = async (io, userA, userB, lastActorId) => {
  try {
    const sorted = [userA.toString(), userB.toString()].sort();
    const u1 = sorted[0];
    const u2 = sorted[1];

    let streak = await InteractionStreak.findOne({ user1: u1, user2: u2 });

    const now = new Date();
    if (!streak) {
      streak = await InteractionStreak.create({
        user1: u1,
        user2: u2,
        streakCount: 1,
        lastInteractionTime: now,
        lastInteractionUserId: lastActorId,
        status: 'active',
      });
      return streak;
    }

    const lastInteraction = new Date(streak.lastInteractionTime);
    const hoursElapsed = (now - lastInteraction) / (1000 * 60 * 60);

    // If it's a NEW calendar day (relative to last interaction) and within grace window
    // For simplicity, we use a 24h cooldown to prevent spamming count
    const isSameActor = streak.lastInteractionUserId === lastActorId.toString();
    const isNextInteraction = hoursElapsed > 12; // Prevent spamming within same session

    if (hoursElapsed > STREAK_GRACE_HOURS) {
      // Streak broken
      streak.streakCount = 1;
      streak.status = 'active';
      streak.lastInteractionTime = now;
      streak.lastInteractionUserId = lastActorId;
      streak.warningSent = false;
    } else if (isNextInteraction) {
      // Increment only if it's the other person replying OR if enough time has passed
      // But rules say: "Streak increases ONLY when BOTH users interact within 24 hours"
      // So we check if the LAST interaction was from the OTHER user.
      if (!isSameActor) {
        streak.streakCount += 1;
        streak.lastInteractionTime = now;
        streak.lastInteractionUserId = lastActorId;
        streak.warningSent = false;

        // Check for rewards (3, 7, 30 days)
        await checkInteractionRewards(userA, userB, streak.streakCount);
        
        // Notify both about streak increment
        await notifyStreakProgress(io, userA, userB, streak.streakCount);
      } else {
        // Just refresh the time if it's the same user but within valid window
        streak.lastInteractionTime = now;
      }
    }

    await streak.save();
    return streak;
  } catch (error) {
    console.error('UpdateInteractionStreak Error:', error);
    return null;
  }
};

/**
 * Updates the personal login streak.
 */
exports.updateLoginStreak = async (userId) => {
  try {
    let streak = await LoginStreak.findOne({ userId });
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    if (!streak) {
      streak = await LoginStreak.create({
        userId,
        currentStreak: 1,
        lastLoginDate: today,
        longestStreak: 1,
      });
      await grantLoginReward(userId, 1);
      return streak;
    }

    const lastLogin = new Date(streak.lastLoginDate);
    const diffTime = today - lastLogin;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 1) {
      // Next consecutive day
      streak.currentStreak += 1;
      streak.lastLoginDate = today;
      if (streak.currentStreak > streak.longestStreak) {
        streak.longestStreak = streak.currentStreak;
      }
      await grantLoginReward(userId, streak.currentStreak);
    } else if (diffDays > 1) {
      // Streak broken
      streak.currentStreak = 1;
      streak.lastLoginDate = today;
      await grantLoginReward(userId, 1);
    }
    // if diffDays === 0, already logged in today, do nothing

    await streak.save();

    // Sync back to User for fast UI reads
    await User.findByIdAndUpdate(userId, { 
      'gamification.streakDays': streak.currentStreak 
    });

    return streak;
  } catch (error) {
    console.error('UpdateLoginStreak Error:', error);
    return null;
  }
};

// Internal Helpers
async function checkInteractionRewards(userA, userB, count) {
  const milestones = [
    { days: 3, coins: 10 },
    { days: 7, coins: 50 },
    { days: 30, coins: 500 }
  ];

  const milestone = milestones.find(m => m.days === count);
  if (milestone) {
    await grantInteractionReward(userA, milestone.coins, count, userB);
    await grantInteractionReward(userB, milestone.coins, count, userA);
  }
}

async function grantInteractionReward(userId, amount, milestone, peerId) {
  await User.findByIdAndUpdate(userId, { $inc: { 'gamification.coins': amount } });
  await Reward.create({
    userId,
    rewardType: 'interaction_streak',
    value: amount,
    milestone,
    metadata: { targetUserId: peerId }
  });
}

async function grantLoginReward(userId, count) {
  // 1 coin per day, bonus on milestones
  let amount = 1;
  if (count === 7) amount = 20;
  if (count === 30) amount = 100;

  await User.findByIdAndUpdate(userId, { $inc: { 'gamification.coins': amount } });
  await Reward.create({
    userId,
    rewardType: 'login_streak',
    value: amount,
    milestone: count
  });
}

async function notifyStreakProgress(io, userA, userB, count) {
  const actor = await User.findById(userA).select('username');
  await createAndEmitNotification(io, {
    userId: userB,
    actorUserId: userA,
    type: 'streak_increment',
    title: '🔥 Streak Level Up!',
    body: `Your streak with ${actor.username} is now ${count}!`,
    entityType: 'interaction_streak',
  });
}
