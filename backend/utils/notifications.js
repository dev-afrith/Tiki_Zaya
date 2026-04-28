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
  const actorId = notification.actorUserId || notification.senderId;
  const actor = actorId && actorId !== 'system'
    ? await User.findById(actorId).select('username profilePic')
    : null;

  return {
    _id: notification._id,
    userId: notification.userId,
    senderId: actorId, // keep for backward compatibility
    actorUserId: actorId,
    type: notification.type,
    title: notification.title || '',
    message: notification.body || notification.message || '',
    body: notification.body || notification.message || '',
    videoId: notification.entityId || notification.videoId || '',
    entityId: notification.entityId || notification.videoId || '',
    entityType: notification.entityType || '',
    actor,
    isRead: notification.isRead === true || notification.readAt != null,
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
    senderId: data.actorUserId.toString(),
    actorUserId: data.actorUserId.toString(),
    type: data.type,
    title: data.title || '',
    message: data.body,
    body: data.body,
    videoId: data.entityId ? data.entityId.toString() : '',
    entityId: data.entityId ? data.entityId.toString() : '',
    entityType: data.entityType || '',
  });

  const payload = await buildPayload(notification);
  
  // Compute unread count to emit
  const unreadCount = await Notification.countDocuments({ 
    userId: data.userId.toString(), 
    $or: [{ isRead: false }, { isRead: { $exists: false }, readAt: null }] 
  });

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
    actorUserId: data.actorUserId || 'system',
    type: data.type,
    title: data.title || '',
    message: data.body,
    body: data.body,
    videoId: data.entityId ? data.entityId.toString() : '',
    entityId: data.entityId ? data.entityId.toString() : '',
    entityType: data.entityType || '',
  });

  const payload = await buildPayload(notification);
  
  const unreadCount = await Notification.countDocuments({ 
    userId: data.userId.toString(), 
    $or: [{ isRead: false }, { isRead: { $exists: false }, readAt: null }] 
  });

  if (io) {
    io.to(notification.userId).emit('new_notification', { notification: payload, unreadCount });
  }

  // Fire FCM Push
  await sendFcmPush(data.userId, payload);

  return payload;
};

exports.buildNotificationPayload = buildPayload;
