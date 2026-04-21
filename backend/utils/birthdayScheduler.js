const admin = require('firebase-admin');
const User = require('../models/User');
const { createSystemNotification } = require('./notifications');

const sameMonthDay = (left, right) => left.getMonth() === right.getMonth() && left.getDate() === right.getDate();

const sameCalendarDay = (left, right) => {
  if (!left) return false;
  const date = new Date(left);
  return date.getFullYear() === right.getFullYear() &&
    date.getMonth() === right.getMonth() &&
    date.getDate() === right.getDate();
};

const sendBirthdayPush = async (user) => {
  const tokens = (user.fcmTokens || []).map((item) => item.token).filter(Boolean);
  if (!tokens.length || !admin.apps.length) return;

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: 'TikiZaya',
      body: '🎉 Happy Birthday from TikiZaya!',
    },
    data: {
      type: 'birthday',
    },
  });
};

const runBirthdayNotifications = async (io, now = new Date()) => {
  const users = await User.find({
    dateOfBirth: { $ne: null },
    status: 'active',
  }).select('dateOfBirth birthdayNotificationLastSentAt fcmTokens gamification');

  let sent = 0;
  for (const user of users) {
    const dob = new Date(user.dateOfBirth);
    if (!sameMonthDay(dob, now) || sameCalendarDay(user.birthdayNotificationLastSentAt, now)) {
      continue;
    }

    await createSystemNotification(io, {
      userId: user._id,
      type: 'birthday',
      title: '🎉 Happy Birthday from TikiZaya!',
      body: 'We added a small birthday reward to your account.',
    });

    if (!user.gamification) user.gamification = {};
    user.gamification.points = Number(user.gamification.points || 0) + 25;
    user.birthdayNotificationLastSentAt = now;
    await user.save();
    await sendBirthdayPush(user);
    sent += 1;
  }
  return sent;
};

const startBirthdayScheduler = (io) => {
  const intervalMs = Number(process.env.BIRTHDAY_JOB_INTERVAL_MS || 60 * 60 * 1000);
  const tick = async () => {
    try {
      const count = await runBirthdayNotifications(io);
      if (count > 0) console.log(`[BIRTHDAY] Sent ${count} birthday notifications`);
    } catch (error) {
      console.error('[BIRTHDAY] Scheduler failed:', error.message);
    }
  };

  setTimeout(tick, 30 * 1000).unref();
  setInterval(tick, intervalMs).unref();
};

module.exports = {
  runBirthdayNotifications,
  startBirthdayScheduler,
};
