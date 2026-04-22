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
        title: payload.title || 'Tiki Zaya',
        body: payload.body || 'You have a new notification',
      },
      data: {
        type: payload.type || '',
        entityId: payload.entityId || '',
        actorUserId: payload.actorUserId || '',
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
  const actor = notification.actorUserId && notification.actorUserId !== 'system'
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

  // Fire FCM Push
  await sendFcmPush(data.userId, payload);

  return payload;
};

exports.createSystemNotification = async (io, data) => {
  if (!data.userId) return null;

  const notification = await Notification.create({
    userId: data.userId.toString(),
    actorUserId: data.actorUserId || 'system',
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

  // Fire FCM Push
  await sendFcmPush(data.userId, payload);

  return payload;
};

exports.buildNotificationPayload = buildPayload;
