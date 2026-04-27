const Notification = require('../models/Notification');
const { buildNotificationPayload } = require('../utils/notifications');

exports.getNotifications = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const notifications = await Notification.find({ userId: req.userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const mapped = [];
    for (const notification of notifications) {
      mapped.push(await buildNotificationPayload(notification));
    }

    const unreadCount = await Notification.countDocuments({ userId: req.userId, isRead: false });
    
    // Check if there's more
    const totalCount = await Notification.countDocuments({ userId: req.userId });
    const hasMore = skip + notifications.length < totalCount;

    res.status(200).json({ notifications: mapped, unreadCount, hasMore, page });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getUnreadCount = async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({ userId: req.userId, isRead: false });
    res.status(200).json({ unreadCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.markAllRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.userId, isRead: false },
      { $set: { isRead: true } }
    );
    res.status(200).json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.markOneRead = async (req, res) => {
  try {
    await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId },
      { $set: { isRead: true } }
    );
    const unreadCount = await Notification.countDocuments({ userId: req.userId, isRead: false });
    res.status(200).json({ ok: true, unreadCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};