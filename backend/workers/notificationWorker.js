const { Worker } = require('bullmq');
const Notification = require('../models/Notification');
const User = require('../models/User');
const admin = require('firebase-admin');

let worker = null;

/**
 * Send FCM push notification to a user's registered devices.
 * Cleans up invalid/expired tokens automatically.
 */
const sendFcmPush = async (userId, payload) => {
  try {
    if (!admin.apps.length) return;

    const user = await User.findById(userId).select('fcmTokens');
    if (!user || !user.fcmTokens || user.fcmTokens.length === 0) return;

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
          resp.error?.code === 'messaging/invalid-registration-token' ||
          resp.error?.code === 'messaging/registration-token-not-registered'
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
    console.error('[WORKER FCM]', error.message);
  }
};

/**
 * Process a batch of follower notifications.
 * Creates Notification documents in bulk and emits Socket.io events.
 */
const processFollowerBatch = async (job) => {
  const { authorId, authorUsername, videoId, followerIds, batchIndex } = job.data;

  console.log(`[WORKER] Processing follower batch ${batchIndex} (${followerIds.length} followers)`);

  // Bulk-create notification documents
  const notificationDocs = followerIds
    .filter((fid) => fid !== authorId) // Don't notify yourself
    .map((followerId) => ({
      userId: followerId,
      actorUserId: authorId,
      type: 'post',
      title: 'New post',
      body: `${authorUsername || 'Someone'} has posted a new video`,
      entityType: 'video',
      entityId: videoId,
    }));

  if (notificationDocs.length === 0) return;

  const insertedNotifications = await Notification.insertMany(notificationDocs);

  // Emit Socket.io events (if server IO is accessible via global)
  const io = global.__tikizaya_io;

  // Get actor info for the notification payload
  const actor = await User.findById(authorId).select('username profilePic');

  for (const notification of insertedNotifications) {
    const payload = {
      _id: notification._id,
      userId: notification.userId,
      actorUserId: notification.actorUserId,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      entityType: notification.entityType,
      entityId: notification.entityId,
      actor: actor ? { _id: actor._id, username: actor.username, profilePic: actor.profilePic } : null,
      readAt: null,
      createdAt: notification.createdAt,
    };

    if (io) {
      io.to(notification.userId).emit('new_notification', payload);
    }

    // Send FCM push (fire-and-forget per user)
    sendFcmPush(notification.userId, payload).catch(() => {});
  }

  console.log(`[WORKER] Batch ${batchIndex} complete: ${insertedNotifications.length} notifications created`);
};

/**
 * Process a single notification job.
 */
const processSingle = async (job) => {
  const data = job.data;
  if (!data.userId || !data.actorUserId || data.userId === data.actorUserId) return;

  const notification = await Notification.create({
    userId: data.userId,
    actorUserId: data.actorUserId,
    type: data.type,
    title: data.title,
    body: data.body,
    entityType: data.entityType || '',
    entityId: data.entityId || '',
  });

  const actor = await User.findById(data.actorUserId).select('username profilePic');
  const payload = {
    _id: notification._id,
    userId: notification.userId,
    actorUserId: notification.actorUserId,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    entityType: notification.entityType,
    entityId: notification.entityId,
    actor: actor ? { _id: actor._id, username: actor.username, profilePic: actor.profilePic } : null,
    readAt: null,
    createdAt: notification.createdAt,
  };

  const io = global.__tikizaya_io;
  if (io) {
    io.to(notification.userId).emit('new_notification', payload);
  }

  await sendFcmPush(data.userId, payload);
};

/**
 * Start the notification worker.
 * Must be called after Redis is available.
 */
const start = () => {
  const url = process.env.REDIS_URL;
  if (!url) {
    console.warn('[WORKER] No REDIS_URL — notification worker disabled');
    return null;
  }

  try {
    worker = new Worker(
      'notifications',
      async (job) => {
        switch (job.name) {
          case 'follower-batch':
            await processFollowerBatch(job);
            break;
          case 'single':
            await processSingle(job);
            break;
          default:
            console.warn(`[WORKER] Unknown job name: ${job.name}`);
        }
      },
      {
        connection: {
          url,
          maxRetriesPerRequest: null,
          tls: url.startsWith('rediss://') ? {} : undefined,
        },
        concurrency: 3, // Process up to 3 jobs simultaneously
      }
    );

    worker.on('completed', (job) => {
      // Quiet — avoid noisy logs in production
    });

    worker.on('failed', (job, err) => {
      console.error(`[WORKER] Job ${job?.id} failed:`, err.message);
    });

    console.log('✅ Notification worker started');
    return worker;
  } catch (err) {
    console.error('[WORKER] Start failed:', err.message);
    return null;
  }
};

module.exports = { start };
