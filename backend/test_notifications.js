const mongoose = require('mongoose');
const Notification = require('./models/Notification');
const User = require('./models/User');

require('dotenv').config();

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  const notifications = await Notification.find().sort({ createdAt: -1 }).limit(5);
  for (let n of notifications) {
    const actorId = n.actorUserId || n.senderId;
    const actor = actorId ? await User.findById(actorId).select('username') : null;
    console.log({
      _id: n._id,
      type: n.type,
      body: n.body,
      actorUserId: n.actorUserId,
      actorUsername: actor ? actor.username : null
    });
  }
  process.exit(0);
}

run();
