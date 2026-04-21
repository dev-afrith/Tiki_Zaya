const User = require('../models/User');
const {
  applyDailyLoginBonus,
  buildGamificationSummary,
  claimMilestoneReward,
  claimTaskReward,
  ensureGamificationState,
  recordWatchProgress,
} = require('../utils/gamification');

const emitGamificationUpdate = (req, user) => {
  req.app.get('io')?.to(user._id).emit('gamification_updated', {
    user,
    gamification: buildGamificationSummary(user),
  });
};

const getCurrentUserDoc = async (req) => {
  const user = await User.findById(req.userId);
  if (!user) return null;
  ensureGamificationState(user);
  return user;
};

exports.getMyGamification = async (req, res) => {
  try {
    const user = await getCurrentUserDoc(req);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const dailyReward = applyDailyLoginBonus(user);
    if (dailyReward.awarded) {
      await user.save();
      emitGamificationUpdate(req, user);
    }

    res.status(200).json({
      user,
      gamification: buildGamificationSummary(user),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.claimTask = async (req, res) => {
  try {
    const user = await getCurrentUserDoc(req);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const result = claimTaskReward(user, req.params.taskId);
    if (!result.ok) return res.status(result.status).json({ message: result.message });

    await user.save();
    emitGamificationUpdate(req, user);

    res.status(200).json({
      ok: true,
      awardedPoints: result.awardedPoints,
      task: result.task,
      gamification: buildGamificationSummary(user),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.claimReward = async (req, res) => {
  try {
    const user = await getCurrentUserDoc(req);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const result = claimMilestoneReward(user, req.params.rewardId);
    if (!result.ok) return res.status(result.status).json({ message: result.message });

    await user.save();
    emitGamificationUpdate(req, user);

    res.status(200).json({
      ok: true,
      awardedPoints: result.awardedPoints,
      reward: result.reward,
      gamification: buildGamificationSummary(user),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.recordWatchTime = async (req, res) => {
  try {
    const user = await getCurrentUserDoc(req);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const seconds = req.body?.seconds ?? req.body?.watchSeconds ?? 0;
    const result = recordWatchProgress(user, seconds);
    await user.save();
    emitGamificationUpdate(req, user);

    res.status(200).json({
      ok: true,
      awardedPoints: result.awardedPoints,
      gamification: buildGamificationSummary(user),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getLeaderboard = async (req, res) => {
  try {
    const users = await User.find({ username: { $exists: true, $ne: null } })
      .sort({ 'gamification.points': -1, 'gamification.streakDays': -1, createdAt: 1 })
      .limit(10)
      .select('username name profilePic gamification');

    const leaderboard = users.map((user, index) => ({
      rank: index + 1,
      userId: user._id,
      username: user.username,
      name: user.name || user.username,
      profilePic: user.profilePic || '',
      points: Number(user.gamification?.points || 0),
      streakDays: Number(user.gamification?.streakDays || 0),
      badges: buildGamificationSummary(user).badges,
    }));

    res.status(200).json({ leaderboard });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getAppUpdate = async (req, res) => {
  const installed = (req.query.version || '').toString();
  const latestVersion = process.env.APP_LATEST_VERSION || '1.0.0';
  const latestBuild = Number(process.env.APP_LATEST_BUILD || 1);
  const apkUrl = process.env.APP_APK_URL || 'https://github.com/zayacodehub/tikizaya/releases/latest';
  const changelog = (process.env.APP_CHANGELOG || 'Performance improvements|Rewards fixes|Smoother real-time updates')
    .split('|')
    .map((item) => item.trim())
    .filter(Boolean);

  res.status(200).json({
    latestVersion,
    latestBuild,
    apkUrl,
    changelog,
    updateAvailable: Boolean(installed && installed !== latestVersion),
  });
};
