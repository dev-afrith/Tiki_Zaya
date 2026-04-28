const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true }, // receiver
  senderId: { type: String, index: true }, // actor (old)
  actorUserId: { type: String, index: true }, // actor (new)
  type: { type: String, required: true },
  videoId: { type: String }, // optional (old)
  entityId: { type: String }, // optional (new)
  entityType: { type: String }, // optional (new)
  message: { type: String }, // text (old)
  body: { type: String }, // text (new)
  title: { type: String }, // text (new)
  isRead: { type: Boolean, default: false },
  readAt: { type: Date, default: null },
}, { timestamps: true });

notificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
