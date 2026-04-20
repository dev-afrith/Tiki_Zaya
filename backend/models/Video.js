const mongoose = require('mongoose');

const videoSchema = new mongoose.Schema({
  userId: {
    type: String, // Firebase UID
    ref: 'User',
    required: true
  },
  videoUrl: {
    type: String,
    required: true
  },
  description: {
    type: String,
    default: ''
  },
  caption: {
    type: String,
    default: ''
  },
  likes: [{ type: String, ref: 'User' }],
  likesCount: {
    type: Number,
    default: 0
  },
  favorites: [{ type: String, ref: 'User' }],
  hashtags: [{ type: String, trim: true, lowercase: true }],
  mentions: [{ type: String, trim: true, lowercase: true }],
  thumbnailUrl: {
    type: String,
    default: ''
  },
  commentsCount: {
    type: Number,
    default: 0
  },
  viewsCount: {
    type: Number,
    default: 0
  },
  views: {
    type: Number,
    default: 0
  },
  repostsCount: {
    type: Number,
    default: 0
  },
  sharesCount: {
    type: Number,
    default: 0
  },
  videoDurationSeconds: {
    type: Number,
    default: 0
  },
  isArchived: {
    type: Boolean,
    default: false,
    index: true
  },
  archivedAt: {
    type: Date,
    default: null
  },
  editingMetadata: {
    filter: String,
    speed: { type: Number, default: 1.0 },
    texts: [{
      text: String,
      position: { dx: Number, dy: Number },
      fontSize: Number,
      color: String,
      bold: Boolean
    }]
  }
}, { 
  timestamps: true 
});

module.exports = mongoose.model('Video', videoSchema);
