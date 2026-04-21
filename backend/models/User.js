const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  _id: {
    type: String, // Firebase UID for social auth, generated UUID for local auth
    required: true
  },
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
    match: [/^[a-z0-9_]+$/, 'Please use only lowercase letters, numbers, and underscores']
  },
  email: {
    type: String,
    required: true,
    unique: true,
    sparse: true
  },
  phone: {
    type: String,
    required: true
  },
  passwordHash: {
    type: String,
    default: '',
    select: false,
  },
  passwordUpdatedAt: {
    type: Date,
    default: null,
  },
  emailVerified: {
    type: Boolean,
    default: false,
  },
  phoneVerified: {
    type: Boolean,
    default: false,
  },
  refreshTokens: [{
    tokenHash: { type: String, required: true, select: false },
    device: { type: String, default: '' },
    ip: { type: String, default: '' },
    expiresAt: { type: Date, required: true },
    createdAt: { type: Date, default: Date.now },
  }],
  passwordReset: {
    otpHash: { type: String, default: '', select: false },
    expiresAt: { type: Date, default: null },
  },
  fcmTokens: [{
    token: { type: String, required: true },
    platform: { type: String, default: '' },
    updatedAt: { type: Date, default: Date.now },
  }],
  birthdayNotificationLastSentAt: {
    type: Date,
    default: null,
  },
  role: {
    type: String,
    enum: ['user'],
    default: 'user',
    index: true,
  },
  status: {
    type: String,
    enum: ['active', 'blocked'],
    default: 'active',
    index: true,
  },
  profilePic: {
    type: String,
    default: ''
  },
  profilePhotoUrl: {
    type: String,
    default: ''
  },
  name: {
    type: String,
    default: '',
    trim: true,
    maxlength: 60,
  },
  bio: {
    type: String,
    default: '',
    maxlength: 200,
  },
  dateOfBirth: {
    type: Date,
    default: null,
  },
  category: {
    type: String,
    default: '',
    trim: true,
    enum: ['', 'Tech', 'Gaming', 'Education', 'Fitness', 'Lifestyle', 'Travel', 'Music', 'Comedy', 'Other'],
  },
  socialLinks: {
    instagram: { type: String, default: '', trim: true },
    youtube: { type: String, default: '', trim: true },
    website: { type: String, default: '', trim: true },
  },
  themePreference: {
    type: String,
    enum: ['light', 'dark'],
    default: 'dark',
  },
  gamification: {
    points: { type: Number, default: 0 },
    welcomeBonusGrantedAt: { type: Date, default: null },
    firstLoginAt: { type: Date, default: null },
    lastLoginAt: { type: Date, default: null },
    streakDays: { type: Number, default: 0 },
    longestStreak: { type: Number, default: 0 },
    streakRewardsClaimed: { type: [Number], default: [] },
    completedTaskIds: { type: [String], default: [] },
    claimedRewardIds: { type: [String], default: [] },
    lastWatchAt: { type: Date, default: null },
    watchSecondsToday: { type: Number, default: 0 },
    watchRewardedMinutesToday: { type: Number, default: 0 },
    watchSecondsTotal: { type: Number, default: 0 },
    likesGivenTotal: { type: Number, default: 0 },
    commentsGivenTotal: { type: Number, default: 0 },
    uploadsTotal: { type: Number, default: 0 },
    invitesTotal: { type: Number, default: 0 },
  },
  nameChangeHistory: {
    type: [Date],
    default: [],
  },
  country: {
    type: String,
    default: ''
  },
  isPrivate: {
    type: Boolean,
    default: false
  },
  followers: [{ type: String, ref: 'User' }], // References Firebase UIDs
  following: [{ type: String, ref: 'User' }],  // References Firebase UIDs
  reposts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Video' }]
}, { 
  timestamps: true,
  _id: false // Disable auto-generation of ObjectIds because we use Firebase UIDs
});

userSchema.set('toJSON', {
  transform: (_doc, ret) => {
    delete ret.passwordHash;
    delete ret.refreshTokens;
    delete ret.passwordReset;
    return ret;
  },
});

module.exports = mongoose.model('User', userSchema);
