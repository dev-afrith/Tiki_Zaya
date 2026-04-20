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
    maxlength: 1000,
  },
  messageType: {
    type: String,
    enum: ['text', 'reel'],
    default: 'text',
    index: true,
  },
  sharedVideo: {
    videoId: { type: String, default: '' },
    videoUrl: { type: String, default: '' },
    thumbnailUrl: { type: String, default: '' },
    caption: { type: String, default: '' },
    ownerId: { type: String, default: '' },
    ownerUsername: { type: String, default: '' },
  },
  readAt: {
    type: Date,
    default: null,
  },
}, { timestamps: true });

messageSchema.index({ fromUserId: 1, toUserId: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);
