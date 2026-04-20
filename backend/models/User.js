const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  _id: {
    type: String, // Firebase UID
    required: true
  },
  username: {
    type: String,
    required: false, // Set to false to allow auto-creation of partial user documents
    unique: true,
    index: { unique: true, sparse: true }, // Allows multiple users to have a null username initially
    trim: true,
    lowercase: true,
    match: [/^[a-z0-9_]+$/, 'Please use only lowercase letters, numbers, and underscores']
  },
  email: {
    type: String,
    unique: true,
    sparse: true
  },
  phone: {
    type: String,
    unique: true,
    sparse: true
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

module.exports = mongoose.model('User', userSchema);
