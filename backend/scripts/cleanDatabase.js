const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Connect to MongoDB
const MONGO_URI = process.env.MONGO_URI || process.env.DATABASE_URL;

if (!MONGO_URI) {
  console.error('❌ Missing MONGO_URI in .env file.');
  process.exit(1);
}

// Map exactly to your existing models
const User = require('../models/User');
const Video = require('../models/Video');
const Comment = require('../models/Comment');
const Message = require('../models/Message');

async function cleanDatabase() {
  try {
    console.log('⏳ Connecting to Database...');
    await mongoose.connect(MONGO_URI);
    console.log('✅ Connected.');

    console.log('\n🗑️  Starting cleanup process...');

    // Warning: Only run conditionally if sure!
    // Delete all users except for an admin if one exists (by role 'admin')
    const userResult = await User.deleteMany({ role: { $ne: 'admin' } });
    console.log(`- Deleted ${userResult.deletedCount} Users (kept admins if any).`);

    const videoResult = await Video.deleteMany({});
    console.log(`- Deleted ${videoResult.deletedCount} Videos.`);

    const commentResult = await Comment.deleteMany({});
    console.log(`- Deleted ${commentResult.deletedCount} Comments.`);

    const msgResult = await Message.deleteMany({});
    console.log(`- Deleted ${msgResult.deletedCount} Messages.`);

    console.log('\n🎉 Database successfully cleaned for production!');
    console.log('Structure, indexes, and relations are completely safe.');
  } catch (error) {
    console.error('❌ Error cleaning database:', error);
  } finally {
    await mongoose.disconnect();
    console.log('👋 Disconnected.');
    process.exit(0);
  }
}

cleanDatabase();
