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

// ─── Indexes for query optimization ───
videoSchema.index({ isArchived: 1, createdAt: -1 });           // Feed query
videoSchema.index({ userId: 1, isArchived: 1, createdAt: -1 }); // User profile videos
videoSchema.index({ hashtags: 1 });                             // Hashtag search
videoSchema.index({ views: -1 });                               // Trending / discovery sort
videoSchema.index({ likesCount: -1 });                          // Engagement-based queries

module.exports = mongoose.model('Video', videoSchema);
