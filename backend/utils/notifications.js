const Notification = require('../models/Notification');
const User = require('../models/User');

const buildPayload = async (notification) => {
  const actor = notification.actorUserId
    ? await User.findById(notification.actorUserId).select('username profilePic')
    : null;

  return {
    _id: notification._id,
    userId: notification.userId,
    actorUserId: notification.actorUserId,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    entityType: notification.entityType,
    entityId: notification.entityId,
    actor,
    readAt: notification.readAt,
    createdAt: notification.createdAt,
  };
};

exports.createAndEmitNotification = async (io, data) => {
  if (!data.userId || !data.actorUserId || data.userId.toString() === data.actorUserId.toString()) {
    return null;
  }

  const notification = await Notification.create({
    userId: data.userId.toString(),
    actorUserId: data.actorUserId.toString(),
    type: data.type,
    title: data.title,
    body: data.body,
    entityType: data.entityType || '',
    entityId: data.entityId ? data.entityId.toString() : '',
  });

  const payload = await buildPayload(notification);
  if (io) {
    io.to(notification.userId).emit('new_notification', payload);
  }

  return payload;
};

exports.buildNotificationPayload = buildPayload;