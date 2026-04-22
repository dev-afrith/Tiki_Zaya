const User = require('../models/User');
const agoraService = require('../services/agoraService');
const admin = require('firebase-admin');

// Helper to generate a numeric UID for Agora from MongoDB ID
const generateNumericUid = (mongoId) => {
  let hash = 0;
  const str = mongoId.toString();
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0; // Convert to 32bit integer
  }
  return Math.abs(hash);
};

exports.initiateCall = async (req, res) => {
  try {
    const { toUserId, type } = req.body; // type: 'voice' or 'video'
    const fromUserId = req.userId;

    if (!toUserId || !type) {
      return res.status(400).json({ error: 'toUserId and type are required' });
    }

    const [caller, receiver] = await Promise.all([
      User.findById(fromUserId),
      User.findById(toUserId)
    ]);

    if (!receiver) {
      return res.status(404).json({ error: 'Receiver not found' });
    }

    // Generate unique channel name: call_user1_user2
    const sortedIds = [fromUserId, toUserId].sort();
    const channelName = `call_${sortedIds[0]}_${sortedIds[1]}`;
    
    // Generate numeric UIDs
    const callerUid = generateNumericUid(fromUserId);
    const receiverUid = generateNumericUid(toUserId);

    // Generate Agora Tokens (Short expiry: 5 mins)
    const callerToken = agoraService.generateRtcToken(channelName, callerUid, 'publisher', 300);
    const receiverToken = agoraService.generateRtcToken(channelName, receiverUid, 'publisher', 300);

    // Send FCM Signaling (Data message)
    if (receiver.fcmToken) {
      const message = {
        token: receiver.fcmToken,
        data: {
          type: 'incoming_call',
          callType: type,
          channelName: channelName,
          agoraToken: receiverToken,
          callerId: fromUserId,
          callerName: caller.name || caller.username || 'Someone',
          callerPic: caller.profilePic || '',
          receiverUid: receiverUid.toString(),
          timestamp: Date.now().toString()
        },
        android: {
          priority: 'high',
          ttl: 30000 // 30 seconds
        },
        apns: {
          payload: {
            aps: {
              'content-available': 1,
            },
          },
        },
      };

      try {
        await admin.messaging().send(message);
      } catch (fcmError) {
        console.error('FCM signaling failed:', fcmError);
      }
    }

    return res.status(200).json({
      channelName,
      token: callerToken,
      uid: callerUid,
      receiverUid
    });
  } catch (error) {
    console.error('InitiateCall Error:', error);
    return res.status(500).json({ error: error.message });
  }
};

exports.handleCallAction = async (req, res) => {
  try {
    const { toUserId, action, channelName } = req.body; // action: 'reject' or 'busy'
    const fromUserId = req.userId;

    const receiver = await User.findById(toUserId);
    if (receiver && receiver.fcmToken) {
      let data = {
        type: 'call_action',
        action: action,
        channelName: channelName,
        fromUserId: fromUserId
      };

      let notification = undefined;
      if (action === 'missed') {
        const caller = await User.findById(fromUserId);
        notification = {
          title: 'Missed call',
          body: `You have a missed call from ${caller.name || caller.username || 'Someone'}`
        };
        data.type = 'missed_call';
      }

      const message = {
        token: receiver.fcmToken,
        data: data,
        notification: notification
      };
      await admin.messaging().send(message);
    }

    return res.status(200).json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
