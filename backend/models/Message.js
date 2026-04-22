const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  fromUserId: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  toUserId: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  text: {
    type: String,
    default: '',
    trim: true,
    maxlength: 2000,
  },
  messageType: {
    type: String,
    enum: ['text', 'image', 'reel', 'call', 'voice'],
    default: 'text',
    index: true,
  },
  imageUrl: {
    type: String,
    default: '',
  },
  sharedVideo: {
    videoId: { type: String, default: '' },
    videoUrl: { type: String, default: '' },
    thumbnailUrl: { type: String, default: '' },
    caption: { type: String, default: '' },
    ownerId: { type: String, default: '' },
    ownerUsername: { type: String, default: '' },
  },
  status: {
    type: String,
    enum: ['sent', 'delivered', 'seen'],
    default: 'sent',
  },
  deliveredAt: {
    type: Date,
    default: null,
  },
  readAt: {
    type: Date,
    default: null,
  },
  clientMessageId: {
    type: String,
    index: true,
  },
}, { timestamps: true });

messageSchema.index({ fromUserId: 1, toUserId: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);
