const Message = require('../models/Message');
const User = require('../models/User');
const cloudinary = require('cloudinary').v2;
const fs = require('fs');
const { canSendMessage } = require('../utils/chatPermissions');
const { createAndEmitNotification } = require('../utils/notifications');
const streakService = require('../services/streakService');
const InteractionStreak = require('../models/InteractionStreak');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const populateMessage = (query) => {
  return query
    .populate('fromUserId', 'username profilePic isPrivate')
    .populate('toUserId', 'username profilePic isPrivate');
};

exports.getConversation = async (req, res) => {
  try {
    const currentUserId = req.userId;
    const otherUserId = req.params.userId;

    const currentUser = await User.findById(currentUserId);
    const otherUser = await User.findById(otherUserId);

    if (!currentUser || !otherUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    const allowed = canSendMessage({ sender: currentUser, recipient: otherUser }) ||
      canSendMessage({ sender: otherUser, recipient: currentUser });

    if (!allowed) {
      return res.status(403).json({ message: 'Conversation not allowed by privacy settings' });
    }

    const messages = await populateMessage(
      Message.find({
        $or: [
          { fromUserId: currentUserId, toUserId: otherUserId },
          { fromUserId: otherUserId, toUserId: currentUserId },
        ],
      }).sort({ createdAt: 1 }).limit(200)
    );

    // Mark peer messages as seen when conversation is opened
    await Message.updateMany(
      {
        fromUserId: otherUserId,
        toUserId: currentUserId,
        readAt: null,
      },
      { $set: { readAt: new Date(), status: 'seen' } }
    );

    return res.status(200).json(messages);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const fromUserId = req.userId;
    const toUserId = req.params.userId;
    const messageType = (req.body.messageType || 'text').toString();
    const text = (req.body.text || '').trim();
    const sharedVideo = req.body.sharedVideo && typeof req.body.sharedVideo === 'object'
      ? req.body.sharedVideo
      : null;

    if (messageType === 'text' && !text) {
      return res.status(400).json({ message: 'Message text is required' });
    }

    if (messageType === 'reel') {
      if (!sharedVideo || !sharedVideo.videoUrl) {
        return res.status(400).json({ message: 'Reel share payload is required' });
      }
    }

    if (messageType === 'image' && !req.file) {
      return res.status(400).json({ message: 'Image file is required' });
    }

    const sender = await User.findById(fromUserId);
    const recipient = await User.findById(toUserId);

    if (!sender || !recipient) {
      return res.status(404).json({ message: 'User not found' });
    }

    const allowed = canSendMessage({ sender, recipient });
    if (!allowed) {
      return res.status(403).json({ message: 'Messaging not allowed by privacy settings' });
    }

    // Handle image upload to Cloudinary
    let imageUrl = '';
    if (messageType === 'image' && req.file) {
      try {
        const uploadPath = req.file.path;
        const result = await cloudinary.uploader.upload(uploadPath, {
          resource_type: 'image',
          folder: 'tikizaya/chat_images',
          transformation: [
            { width: 1200, height: 1200, crop: 'limit', quality: 'auto:good' },
          ],
        });
        imageUrl = result.secure_url;

        // Clean up temp file
        fs.unlink(uploadPath, () => {});
      } catch (uploadError) {
        if (req.file?.path) fs.unlink(req.file.path, () => {});
        return res.status(500).json({ message: 'Failed to upload image' });
      }
    }

    const clientMessageId = req.body.clientMessageId;
    const message = await Message.create({
      fromUserId,
      toUserId,
      clientMessageId,
      text: messageType === 'image'
        ? (text || '')
        : (messageType === 'text' || messageType === 'voice' || messageType === 'call')
          ? text
          : (text || 'Shared a reel'),
      messageType: ['reel', 'call', 'voice', 'image'].includes(messageType) ? messageType : 'text',
      imageUrl,
      status: 'sent',
      sharedVideo: messageType === 'reel'
        ? {
            videoId: (sharedVideo.videoId || '').toString(),
            videoUrl: (sharedVideo.videoUrl || '').toString(),
            thumbnailUrl: (sharedVideo.thumbnailUrl || '').toString(),
            caption: (sharedVideo.caption || '').toString(),
            ownerId: (sharedVideo.ownerId || '').toString(),
            ownerUsername: (sharedVideo.ownerUsername || '').toString(),
          }
        : undefined,
    });

    // Build notification body based on message type
    let notifBody = `${sender.username || 'Someone'} sent you a message`;
    if (messageType === 'image') {
      notifBody = `${sender.username || 'Someone'} sent a photo`;
    } else if (messageType === 'voice') {
      notifBody = `${sender.username || 'Someone'} sent a voice message`;
    } else if (messageType === 'reel') {
      notifBody = `${sender.username || 'Someone'} shared a reel`;
    }

    await createAndEmitNotification(req.app.get('io'), {
      userId: toUserId,
      actorUserId: fromUserId,
      type: 'message',
      title: 'New message',
      body: notifBody,
      entityType: 'message',
      entityId: message._id,
    });

    const populated = await populateMessage(Message.findById(message._id));

    // Emit via socket for real-time delivery
    const io = req.app.get('io');
    if (io) {
      const room = [fromUserId, toUserId].sort().join('__');
      io.to(room).emit('new_message', populated);
    }

    // Update interaction streak for valid messages (text, image, reel, voice)
    if (['text', 'image', 'reel', 'voice'].includes(messageType)) {
      streakService.updateInteractionStreak(req.app.get('io'), fromUserId, toUserId, fromUserId);
    }

    return res.status(201).json(populated);
  } catch (error) {
    if (req.file?.path) fs.unlink(req.file.path, () => {});
    return res.status(500).json({ error: error.message });
  }
};

exports.getInbox = async (req, res) => {
  try {
    const currentUserId = req.userId;

    const latest = await Message.aggregate([
      {
        $match: {
          $or: [
            { fromUserId: currentUserId },
            { toUserId: currentUserId },
          ],
        },
      },
      { $sort: { createdAt: -1 } },
      {
        $addFields: {
          peerId: {
            $cond: [
              { $eq: ['$fromUserId', currentUserId] },
              '$toUserId',
              '$fromUserId',
            ],
          },
        },
      },
      {
        $group: {
          _id: '$peerId',
          latestMessageId: { $first: '$_id' },
          latestText: {
            $first: {
              $switch: {
                branches: [
                  { case: { $eq: ['$messageType', 'reel'] }, then: 'Shared a reel' },
                  { case: { $eq: ['$messageType', 'voice'] }, then: '🎵 Voice message' },
                  { case: { $eq: ['$messageType', 'call'] }, then: '📞 Call' },
                  { case: { $eq: ['$messageType', 'image'] }, then: '📷 Photo' },
                ],
                default: '$text'
              }
            },
          },
          latestAt: { $first: '$createdAt' },
          latestMessageType: { $first: '$messageType' },
          fromUserId: { $first: '$fromUserId' },
          toUserId: { $first: '$toUserId' },
          unreadCount: {
            $sum: {
              $cond: [
                {
                  $and: [
                    { $eq: ['$toUserId', currentUserId] },
                    { $eq: ['$readAt', null] },
                  ],
                },
                1,
                0,
              ],
            },
          },
        },
      },
      { $sort: { latestAt: -1 } },
    ]);

    const peerIds = latest.map((item) => item._id);
    const peers = await User.find({ _id: { $in: peerIds } }).select('username profilePic isPrivate');
    const peerMap = Object.fromEntries(peers.map((u) => [u._id, u]));

    const inbox = latest
      .map((item) => ({
        user: peerMap[item._id],
        latestText: item.latestText,
        latestAt: item.latestAt,
        latestMessageType: item.latestMessageType || 'text',
        unreadCount: item.unreadCount || 0,
      }))
      .filter((item) => Boolean(item.user));

    const unreadTotal = inbox.reduce((sum, item) => sum + (item.unreadCount || 0), 0);

    return res.status(200).json({ inbox, unreadTotal });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getUnreadCount = async (req, res) => {
  try {
    const unreadTotal = await Message.countDocuments({
      toUserId: req.userId,
      readAt: null,
    });

    return res.status(200).json({ unreadTotal });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.markConversationRead = async (req, res) => {
  try {
    const currentUserId = req.userId;
    const otherUserId = req.params.userId;

    const result = await Message.updateMany(
      {
        fromUserId: otherUserId,
        toUserId: currentUserId,
        readAt: null,
      },
      { $set: { readAt: new Date(), status: 'seen' } }
    );

    // Emit seen status via socket
    const io = req.app.get('io');
    if (io && result.modifiedCount > 0) {
      const room = [currentUserId, otherUserId].sort().join('__');
      io.to(room).emit('messages_seen', {
        seenBy: currentUserId,
        seenAt: new Date().toISOString(),
      });
    }

    return res.status(200).json({ ok: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.acknowledgeReelWatch = async (req, res) => {
  try {
    const userId = req.userId;
    const { messageId, durationWatched } = req.body;

    if (!messageId || !durationWatched) {
      return res.status(400).json({ message: 'messageId and durationWatched are required' });
    }

    const message = await Message.findById(messageId);
    if (!message || message.messageType !== 'reel') {
      return res.status(404).json({ message: 'Reel message not found' });
    }

    // Validation: 3s or 30% rule
    // We can assume the frontend did its job, but backend source of truth check:
    const video = await require('../models/Video').findById(message.sharedVideo.videoId);
    const totalDuration = video ? video.videoDurationSeconds : 0;
    
    const threshold = 3.0; 
    const percentageThreshold = totalDuration > 0 ? totalDuration * 0.3 : threshold;
    const target = threshold < percentageThreshold ? threshold : percentageThreshold;

    if (durationWatched >= target) {
      // Trigger interaction streak update
      const fromUserId = message.fromUserId.toString();
      const toUserId = message.toUserId.toString();
      
      // The interaction is between the sender and receiver.
      // In this context, the person watching (userId) is the one fulfilling the streak condition.
      await streakService.updateInteractionStreak(req.app.get('io'), fromUserId, toUserId, userId);
      
      return res.status(200).json({ success: true, message: 'Reel interaction acknowledged' });
    }

    return res.status(400).json({ success: false, message: 'Watch duration below threshold' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
