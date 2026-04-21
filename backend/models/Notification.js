const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  actorUserId: { type: String, required: true, index: true },
  type: { type: String, required: true, enum: ['like', 'message', 'follow', 'comment', 'repost', 'post', 'birthday'] },
  title: { type: String, required: true },
  body: { type: String, required: true },
  entityType: { type: String },
  entityId: { type: String },
  readAt: { type: Date, default: null },
}, { timestamps: true });

notificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
