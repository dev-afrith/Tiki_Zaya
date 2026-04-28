const mongoose = require('mongoose');
require('dotenv').config();

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  const db = mongoose.connection.db;
  const notifications = await db.collection('notifications').find().sort({ createdAt: -1 }).limit(5).toArray();
  for (let n of notifications) {
    console.log(n);
  }
  process.exit(0);
}

run();
