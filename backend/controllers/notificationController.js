const Notification = require('../models/Notification');
const { buildNotificationPayload } = require('../utils/notifications');

exports.getNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.userId })
      .sort({ createdAt: -1 })
      .limit(40);

    const mapped = [];
    for (const notification of notifications) {
      mapped.push(await buildNotificationPayload(notification));
    }

    const unreadCount = await Notification.countDocuments({ userId: req.userId, readAt: null });
    res.status(200).json({ notifications: mapped, unreadCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.markAllRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.userId, readAt: null },
      { $set: { readAt: new Date() } }
    );
    res.status(200).json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};