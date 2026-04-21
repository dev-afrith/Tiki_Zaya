const STREAK_MILESTONES = [
  { days: 3, rewardPoints: 10 },
  { days: 7, rewardPoints: 25 },
  { days: 14, rewardPoints: 50 },
  { days: 30, rewardPoints: 100 },
];

const TASK_DEFINITIONS = [
  {
    id: 'upload-post',
    title: 'Upload a post',
    description: 'Share one video with the community.',
    rewardPoints: 75,
    metric: 'uploadsTotal',
    targetValue: 1,
    unit: 'post',
  },
  {
    id: 'like-posts',
    title: 'Like posts',
    description: 'Like 5 posts to support creators.',
    rewardPoints: 25,
    metric: 'likesGivenTotal',
    targetValue: 5,
    unit: 'likes',
  },
  {
    id: 'comment-posts',
    title: 'Comment on posts',
    description: 'Start 3 conversations in comments.',
    rewardPoints: 35,
    metric: 'commentsGivenTotal',
    targetValue: 3,
    unit: 'comments',
  },
  {
    id: 'watch-10',
    title: 'Watch 10 min',
    description: 'Watch 10 minutes of videos today.',
    rewardPoints: 10,
    metric: 'watchMinutesToday',
    targetValue: 10,
    unit: 'min',
  },
  {
    id: 'invite-users',
    title: 'Invite users',
    description: 'Invite 2 friends to TikiZaya.',
    rewardPoints: 100,
    metric: 'invitesTotal',
    targetValue: 2,
    unit: 'invites',
  },
];

const REWARD_DEFINITIONS = [
  { id: 'points-1000', title: '1000 TZ Club', description: 'Milestone reward for reaching 1000 TZ Points.', requiredPoints: 1000, rewardPoints: 125 },
  { id: 'streak-7', title: '7-Day Streak Reward', description: 'Unlocked after keeping a 7-day streak alive.', requiredStreakDays: 7, rewardPoints: 150 },
  { id: 'surprise-2500', title: 'Surprise Reward', description: 'A bonus drop for highly engaged creators.', requiredPoints: 2500, rewardPoints: 350, surprise: true },
];

const WATCH_POINT_RATE_SECONDS = 60;
const WATCH_POINT_VALUE = 1;

const toDayKey = (value) => {
  const date = value ? new Date(value) : new Date();
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
};

const sameCalendarDay = (left, right) => toDayKey(left) === toDayKey(right);

const getGamification = (user) => {
  const gamification = user?.gamification || {};

  return {
    points: Number(gamification.points || 0),
    streakDays: Number(gamification.streakDays || 0),
    longestStreak: Number(gamification.longestStreak || 0),
    firstLoginAt: gamification.firstLoginAt || null,
    welcomeBonusGrantedAt: gamification.welcomeBonusGrantedAt || null,
    lastLoginAt: gamification.lastLoginAt || null,
    lastWatchAt: gamification.lastWatchAt || null,
    watchSecondsToday: Number(gamification.watchSecondsToday || 0),
    watchRewardedMinutesToday: Number(gamification.watchRewardedMinutesToday || 0),
    watchSecondsTotal: Number(gamification.watchSecondsTotal || 0),
    likesGivenTotal: Number(gamification.likesGivenTotal || 0),
    commentsGivenTotal: Number(gamification.commentsGivenTotal || 0),
    uploadsTotal: Number(gamification.uploadsTotal || 0),
    invitesTotal: Number(gamification.invitesTotal || 0),
    completedTaskIds: Array.isArray(gamification.completedTaskIds) ? gamification.completedTaskIds : [],
    claimedRewardIds: Array.isArray(gamification.claimedRewardIds) ? gamification.claimedRewardIds : [],
    streakRewardsClaimed: Array.isArray(gamification.streakRewardsClaimed)
      ? gamification.streakRewardsClaimed.map((item) => Number(item)).filter((item) => Number.isFinite(item))
      : [],
  };
};

const ensureGamificationState = (user) => {
  if (!user.gamification) {
    user.gamification = {};
  }

  const gamification = user.gamification;
  if (typeof gamification.points !== 'number') gamification.points = 0;
  if (typeof gamification.streakDays !== 'number') gamification.streakDays = 0;
  if (typeof gamification.longestStreak !== 'number') gamification.longestStreak = 0;
  if (!Array.isArray(gamification.streakRewardsClaimed)) gamification.streakRewardsClaimed = [];
  if (typeof gamification.watchSecondsToday !== 'number') gamification.watchSecondsToday = 0;
  if (typeof gamification.watchRewardedMinutesToday !== 'number') gamification.watchRewardedMinutesToday = 0;
  if (typeof gamification.watchSecondsTotal !== 'number') gamification.watchSecondsTotal = 0;
  if (typeof gamification.likesGivenTotal !== 'number') gamification.likesGivenTotal = 0;
  if (typeof gamification.commentsGivenTotal !== 'number') gamification.commentsGivenTotal = 0;
  if (typeof gamification.uploadsTotal !== 'number') gamification.uploadsTotal = 0;
  if (typeof gamification.invitesTotal !== 'number') gamification.invitesTotal = 0;
  if (!Array.isArray(gamification.completedTaskIds)) gamification.completedTaskIds = [];
  if (!Array.isArray(gamification.claimedRewardIds)) gamification.claimedRewardIds = [];

  return gamification;
};

const resetDailyWatchStateIfNeeded = (gamification, now = new Date()) => {
  if (!gamification.lastWatchAt) {
    return;
  }

  if (!sameCalendarDay(gamification.lastWatchAt, now)) {
    gamification.watchSecondsToday = 0;
    gamification.watchRewardedMinutesToday = 0;
  }
};

const applyDailyLoginBonus = (user, now = new Date()) => {
  const gamification = ensureGamificationState(user);

  if (!gamification.firstLoginAt) {
    gamification.firstLoginAt = now;
  }

  if (gamification.lastLoginAt && sameCalendarDay(gamification.lastLoginAt, now)) {
    return { awarded: false, streakChanged: false };
  }

  const previousLoginAt = gamification.lastLoginAt ? new Date(gamification.lastLoginAt) : null;
  let streakChanged = false;

  if (!previousLoginAt) {
    gamification.streakDays = 1;
    streakChanged = true;
  } else {
    const elapsedDays = toDayKey(now) - toDayKey(previousLoginAt);
    const oneDay = 24 * 60 * 60 * 1000;
    if (elapsedDays === oneDay) {
      gamification.streakDays = Number(gamification.streakDays || 0) + 1;
    } else {
      gamification.streakDays = 1;
    }
    streakChanged = true;
  }

  gamification.longestStreak = Math.max(Number(gamification.longestStreak || 0), Number(gamification.streakDays || 0));
  gamification.points = Number(gamification.points || 0) + 5;
  gamification.lastLoginAt = now;

  const milestoneRewards = [];
  for (const milestone of STREAK_MILESTONES) {
    if (gamification.streakDays >= milestone.days && !gamification.streakRewardsClaimed.includes(milestone.days)) {
      gamification.points += milestone.rewardPoints;
      gamification.streakRewardsClaimed.push(milestone.days);
      milestoneRewards.push(milestone);
    }
  }

  return { awarded: true, streakChanged, milestoneRewards };
};

const awardFirstLoginBonus = (user, now = new Date()) => {
  const gamification = ensureGamificationState(user);
  if (gamification.welcomeBonusGrantedAt) {
    return false;
  }

  gamification.points = Number(gamification.points || 0) + 100;
  gamification.welcomeBonusGrantedAt = now;
  if (!gamification.firstLoginAt) {
    gamification.firstLoginAt = now;
  }
  return true;
};

const awardLikeBonus = (user) => {
  const gamification = ensureGamificationState(user);
  gamification.points = Number(gamification.points || 0) + 2;
  gamification.likesGivenTotal = Number(gamification.likesGivenTotal || 0) + 1;
  return gamification;
};

const awardCommentBonus = (user) => {
  const gamification = ensureGamificationState(user);
  gamification.points = Number(gamification.points || 0) + 5;
  gamification.commentsGivenTotal = Number(gamification.commentsGivenTotal || 0) + 1;
  return gamification;
};

const recordWatchProgress = (user, seconds, now = new Date()) => {
  const gamification = ensureGamificationState(user);
  resetDailyWatchStateIfNeeded(gamification, now);

  const safeSeconds = Math.max(0, Number(seconds || 0));
  if (safeSeconds === 0) {
    return { awardedPoints: 0, newPoints: gamification.points };
  }

  gamification.watchSecondsToday += safeSeconds;
  gamification.watchSecondsTotal += safeSeconds;
  gamification.lastWatchAt = now;

  const watchedMinutes = Math.floor(gamification.watchSecondsToday / WATCH_POINT_RATE_SECONDS);
  const rewardableMinutes = watchedMinutes - Number(gamification.watchRewardedMinutesToday || 0);
  const awardedPoints = Math.max(0, rewardableMinutes) * WATCH_POINT_VALUE;

  if (awardedPoints > 0) {
    gamification.points += awardedPoints;
    gamification.watchRewardedMinutesToday += rewardableMinutes;
  }

  return { awardedPoints, newPoints: gamification.points };
};

const buildBadges = (user) => {
  const gamification = getGamification(user);
  const badges = [];

  if (gamification.points >= 100) badges.push('First Steps');
  if (gamification.points >= 500) badges.push('Momentum');
  if (gamification.likesGivenTotal >= 5) badges.push('Supporter');
  if (gamification.commentsGivenTotal >= 3) badges.push('Conversation Starter');
  if (gamification.watchSecondsTotal >= 3600) badges.push('Dedicated Viewer');
  if (gamification.streakDays >= 7) badges.push('7-Day Streak');

  return badges;
};

const buildTasks = (user) => {
  const gamification = getGamification(user);
  const watchMinutes = Math.floor(Number(gamification.watchSecondsToday || 0) / 60);

  const values = {
    uploadsTotal: Number(gamification.uploadsTotal || 0),
    likesGivenTotal: Number(gamification.likesGivenTotal || 0),
    commentsGivenTotal: Number(gamification.commentsGivenTotal || 0),
    watchMinutesToday: watchMinutes,
    invitesTotal: Number(gamification.invitesTotal || 0),
  };

  return TASK_DEFINITIONS.map((task) => {
    const currentValue = Math.min(Number(values[task.metric] || 0), task.targetValue);
    const claimable = currentValue >= task.targetValue;
    const claimed = gamification.completedTaskIds.includes(task.id);
    return {
      ...task,
      currentValue,
      completed: claimed,
      claimable,
      status: claimed ? 'claimed' : claimable ? 'claimable' : 'in_progress',
    };
  });
};

const buildRewards = (user) => {
  const gamification = getGamification(user);
  return REWARD_DEFINITIONS.map((reward) => {
    const pointsReady = !reward.requiredPoints || gamification.points >= reward.requiredPoints;
    const streakReady = !reward.requiredStreakDays || gamification.streakDays >= reward.requiredStreakDays;
    const claimable = pointsReady && streakReady;
    const claimed = gamification.claimedRewardIds.includes(reward.id);
    return {
      ...reward,
      claimable,
      claimed,
      status: claimed ? 'claimed' : claimable ? 'claimable' : 'locked',
    };
  });
};

const claimTaskReward = (user, taskId) => {
  const gamification = ensureGamificationState(user);
  const task = buildTasks(user).find((item) => item.id === taskId);
  if (!task) return { ok: false, status: 404, message: 'Task not found' };
  if (gamification.completedTaskIds.includes(taskId)) return { ok: false, status: 409, message: 'Task already claimed' };
  if (!task.claimable) return { ok: false, status: 400, message: 'Task is not complete yet' };
  gamification.points += Number(task.rewardPoints || 0);
  gamification.completedTaskIds.push(taskId);
  return { ok: true, task, awardedPoints: task.rewardPoints };
};

const claimMilestoneReward = (user, rewardId) => {
  const gamification = ensureGamificationState(user);
  const reward = buildRewards(user).find((item) => item.id === rewardId);
  if (!reward) return { ok: false, status: 404, message: 'Reward not found' };
  if (gamification.claimedRewardIds.includes(rewardId)) return { ok: false, status: 409, message: 'Reward already claimed' };
  if (!reward.claimable) return { ok: false, status: 400, message: 'Reward is locked' };
  gamification.points += Number(reward.rewardPoints || 0);
  gamification.claimedRewardIds.push(rewardId);
  return { ok: true, reward, awardedPoints: reward.rewardPoints };
};

const buildRewardProgress = (user, targetPoints = 2500) => {
  const gamification = getGamification(user);
  const currentPoints = Number(gamification.points || 0);
  const safeTarget = Math.max(1, Number(targetPoints || 2500));

  return {
    currentPoints,
    targetPoints: safeTarget,
    remainingPoints: Math.max(0, safeTarget - currentPoints),
    progress: Math.min(1, currentPoints / safeTarget),
  };
};

const buildGamificationSummary = (user) => {
  const gamification = getGamification(user);

  return {
    points: gamification.points,
    streakDays: gamification.streakDays,
    longestStreak: gamification.longestStreak,
    welcomeBonusGrantedAt: gamification.welcomeBonusGrantedAt,
    firstLoginAt: gamification.firstLoginAt,
    lastLoginAt: gamification.lastLoginAt,
    badges: buildBadges(user),
    tasks: buildTasks(user),
    rewards: buildRewards(user),
    rewardProgress: buildRewardProgress(user),
  };
};

module.exports = {
  STREAK_MILESTONES,
  applyDailyLoginBonus,
  awardCommentBonus,
  awardFirstLoginBonus,
  awardLikeBonus,
  buildBadges,
  buildGamificationSummary,
  buildRewards,
  buildRewardProgress,
  buildTasks,
  claimMilestoneReward,
  claimTaskReward,
  ensureGamificationState,
  getGamification,
  recordWatchProgress,
};
