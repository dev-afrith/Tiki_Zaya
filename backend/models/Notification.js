const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true }, // receiver
  senderId: { type: String, required: true, index: true }, // actor
  type: { type: String, required: true, enum: ['like', 'message', 'follow', 'comment', 'repost', 'post', 'birthday'] },
  videoId: { type: String }, // optional
  message: { type: String, required: true }, // text
  isRead: { type: Boolean, default: false },
}, { timestamps: true });

notificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
