const { Queue } = require('bullmq');

let notificationQueue = null;

/**
 * Initialize the notification queue.
 * Uses the same Redis connection configured in REDIS_URL.
 */
const init = () => {
  const url = process.env.REDIS_URL;
  if (!url) {
    console.warn('[NOTIFICATION QUEUE] No REDIS_URL — background jobs disabled');
    return null;
  }

  try {
    notificationQueue = new Queue('notifications', {
      connection: {
        url,
        maxRetriesPerRequest: null,
        tls: url.startsWith('rediss://') ? {} : undefined,
      },
      defaultJobOptions: {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: { count: 500 }, // Keep last 500 completed jobs
        removeOnFail: { count: 200 },
      },
    });

    console.log('✅ Notification queue initialized');
    return notificationQueue;
  } catch (err) {
    console.error('[NOTIFICATION QUEUE] Init failed:', err.message);
    return null;
  }
};

/**
 * Check if the queue is ready.
 */
const isReady = () => notificationQueue !== null;

/**
 * Queue notification jobs for all followers of an author.
 * Instead of processing inline, this pushes a single job to the worker.
 *
 * @param {object} params
 * @param {string} params.authorId - The user who posted
 * @param {string} params.authorUsername - Display name for notification body
 * @param {string} params.videoId - The new video ID
 * @param {string[]} params.followerIds - Array of follower user IDs
 */
const queueFollowerNotifications = async ({ authorId, authorUsername, videoId, followerIds }) => {
  if (!notificationQueue || !followerIds || followerIds.length === 0) return false;

  try {
    // Split into batches of 100 followers per job to avoid huge payloads
    const BATCH_SIZE = 100;
    const batches = [];
    for (let i = 0; i < followerIds.length; i += BATCH_SIZE) {
      batches.push(followerIds.slice(i, i + BATCH_SIZE));
    }

    for (let i = 0; i < batches.length; i++) {
      await notificationQueue.add('follower-batch', {
        authorId,
        authorUsername,
        videoId,
        followerIds: batches[i],
        batchIndex: i,
        totalBatches: batches.length,
      });
    }

    console.log(`[QUEUE] Queued ${batches.length} notification batch(es) for ${followerIds.length} followers`);
    return true;
  } catch (err) {
    console.error('[QUEUE] Failed to queue follower notifications:', err.message);
    return false;
  }
};

/**
 * Queue a single notification (for likes, comments, follows, etc.)
 */
const queueSingleNotification = async (data) => {
  if (!notificationQueue) return false;

  try {
    await notificationQueue.add('single', data);
    return true;
  } catch (err) {
    console.error('[QUEUE] Failed to queue single notification:', err.message);
    return false;
  }
};

/**
 * Get the raw queue instance (for worker).
 */
const getQueue = () => notificationQueue;

module.exports = {
  init,
  isReady,
  queueFollowerNotifications,
  queueSingleNotification,
  getQueue,
};
