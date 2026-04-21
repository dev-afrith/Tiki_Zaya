const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI || process.env.DATABASE_URL || 'mongodb://localhost:27017/tikizaya';

(async () => {
  try {
    console.log('Connecting to', MONGO_URI);
    await mongoose.connect(MONGO_URI);
    const db = mongoose.connection;
    console.log('Connected.');
    
    try {
      await db.collection('users').dropIndex('phone_1');
      console.log('Successfully dropped the phone_1 index.');
    } catch (e) {
      if (e.code === 27) {
        console.log('phone_1 index does not exist.');
      } else {
        console.error('Error dropping phone index:', e.message);
      }
    }
  } catch (error) {
    console.error('Connection error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Done.');
  }
})();
