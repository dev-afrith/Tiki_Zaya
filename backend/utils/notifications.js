const Notification = require('../models/Notification');
const User = require('../models/User');
const admin = require('firebase-admin');

const sendFcmPush = async (userId, payload) => {
  try {
    if (!admin.apps.length) return; // Wait for admin initialization

    const user = await User.findById(userId);
    if (!user || (!user.fcmTokens) || user.fcmTokens.length === 0) return;

    const validTokens = user.fcmTokens.map((t) => t.token);
    if (validTokens.length === 0) return;

    const message = {
      tokens: validTokens,
      notification: {
        title: 'Tiki Zaya',
        body: payload.message || 'You have a new notification',
      },
      data: {
        type: payload.type || '',
        videoId: payload.videoId || '',
        senderId: payload.senderId || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    const failedTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        if (
          resp.error.code === 'messaging/invalid-registration-token' ||
          resp.error.code === 'messaging/registration-token-not-registered'
        ) {
          failedTokens.push(validTokens[idx]);
        }
      }
    });

    if (failedTokens.length > 0) {
      user.fcmTokens = user.fcmTokens.filter((t) => !failedTokens.includes(t.token));
      await user.save();
    }
  } catch (error) {
    console.error('FCM Push Error:', error.message);
  }
};

const buildPayload = async (notification) => {
  const actor = notification.senderId && notification.senderId !== 'system'
    ? await User.findById(notification.senderId).select('username profilePic')
    : null;

  return {
    _id: notification._id,
    userId: notification.userId,
    senderId: notification.senderId,
    type: notification.type,
    message: notification.message,
    videoId: notification.videoId,
    actor,
    isRead: notification.isRead,
    createdAt: notification.createdAt,
  };
};

exports.createAndEmitNotification = async (io, data) => {
  if (!data.userId || !data.actorUserId || data.userId.toString() === data.actorUserId.toString()) {
    return null;
  }

  const notification = await Notification.create({
    userId: data.userId.toString(),
    senderId: data.actorUserId.toString(),
    type: data.type,
    message: data.body,
    videoId: data.entityId ? data.entityId.toString() : '',
  });

  const payload = await buildPayload(notification);
  
  // Compute unread count to emit
  const unreadCount = await Notification.countDocuments({ userId: data.userId.toString(), isRead: false });

  if (io) {
    io.to(notification.userId).emit('new_notification', { notification: payload, unreadCount });
  }

  // Fire FCM Push
  await sendFcmPush(data.userId, payload);

  return payload;
};

exports.createSystemNotification = async (io, data) => {
  if (!data.userId) return null;

  const notification = await Notification.create({
    userId: data.userId.toString(),
    senderId: data.actorUserId || 'system',
    type: data.type,
    message: data.body,
    videoId: data.entityId ? data.entityId.toString() : '',
  });

  const payload = await buildPayload(notification);
  
  const unreadCount = await Notification.countDocuments({ userId: data.userId.toString(), isRead: false });

  if (io) {
    io.to(notification.userId).emit('new_notification', { notification: payload, unreadCount });
  }

  // Fire FCM Push
  await sendFcmPush(data.userId, payload);

  return payload;
};

exports.buildNotificationPayload = buildPayload;
