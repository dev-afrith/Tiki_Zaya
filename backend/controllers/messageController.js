const Message = require('../models/Message');
const User = require('../models/User');
const { canSendMessage } = require('../utils/chatPermissions');
const { createAndEmitNotification } = require('../utils/notifications');

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

    await Message.updateMany(
      {
        fromUserId: otherUserId,
        toUserId: currentUserId,
        readAt: null,
      },
      { $set: { readAt: new Date() } }
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

    const sender = await User.findById(fromUserId);
    const recipient = await User.findById(toUserId);

    if (!sender || !recipient) {
      return res.status(404).json({ message: 'User not found' });
    }

    const allowed = canSendMessage({ sender, recipient });
    if (!allowed) {
      return res.status(403).json({ message: 'Messaging not allowed by privacy settings' });
    }

    const message = await Message.create({
      fromUserId,
      toUserId,
      text: (messageType === 'text' || messageType === 'voice' || messageType === 'call') ? text : (text || 'Shared a reel'),
      messageType: ['reel', 'call', 'voice'].includes(messageType) ? messageType : 'text',
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

    await createAndEmitNotification(req.app.get('io'), {
      userId: toUserId,
      actorUserId: fromUserId,
      type: 'message',
      title: 'New message',
      body: `${sender.username || 'Someone'} has a message for you`,
      entityType: 'message',
      entityId: message._id,
    });

    const populated = await populateMessage(Message.findById(message._id));

    const io = req.app.get('io');
    if (io) {
      const room = [fromUserId, toUserId].sort().join('__');
      io.to(room).emit('new_message', populated);
    }

    return res.status(201).json(populated);
  } catch (error) {
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
                  { case: { $eq: ['$messageType', 'call'] }, then: '📞 Call' }
                ],
                default: '$text'
              }
            },
          },
          latestAt: { $first: '$createdAt' },
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

    await Message.updateMany(
      {
        fromUserId: otherUserId,
        toUserId: currentUserId,
        readAt: null,
      },
      { $set: { readAt: new Date() } }
    );

    return res.status(200).json({ ok: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
