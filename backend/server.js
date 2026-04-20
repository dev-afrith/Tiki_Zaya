const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const { Server } = require('socket.io');
const User = require('./models/User');
const Message = require('./models/Message');
const authMiddleware = require('./middleware/auth');
const { canSendMessage } = require('./utils/chatPermissions');

dotenv.config();

// Global Error Handlers
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
});

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 5001;
let currentPort = Number(PORT);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

app.set('io', io);

// Middleware
app.use(cors());
app.use(express.json());

// Global Request Logger
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Routes
const videoRoutes = require('./routes/videos');
const commentRoutes = require('./routes/comments');
const userRoutes = require('./routes/users');
const messageRoutes = require('./routes/messages');
const notificationRoutes = require('./routes/notifications');

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Tiki Zaya API is running!' });
});

app.use('/api/videos', videoRoutes);
app.use('/api/comments', commentRoutes);
app.use('/api/users', userRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/notifications', notificationRoutes);

const onlineUsers = new Map();

const getRoomId = (a, b) => [a, b].sort().join('__');

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('Missing auth token'));
    }

    const decoded = await authMiddleware.verifyToken(token);
    socket.userId = decoded.uid;
    next();
  } catch (error) {
    next(new Error('Unauthorized socket'));
  }
});

io.on('connection', (socket) => {
  onlineUsers.set(socket.userId, socket.id);
  socket.join(socket.userId);

  socket.on('join_conversation', ({ withUserId }) => {
    if (!withUserId || typeof withUserId !== 'string') return;
    socket.join(getRoomId(socket.userId, withUserId));
  });

  socket.on('send_message', async ({ toUserId, text }, callback) => {
    try {
      if (!toUserId || !text || typeof text !== 'string') {
        callback?.({ ok: false, error: 'Invalid message payload' });
        return;
      }

      const sender = await User.findById(socket.userId);
      const recipient = await User.findById(toUserId);
      if (!sender || !recipient) {
        callback?.({ ok: false, error: 'User not found' });
        return;
      }

      const allowed = canSendMessage({ sender, recipient });
      if (!allowed) {
        callback?.({ ok: false, error: 'Messaging not allowed by privacy settings' });
        return;
      }

      const message = await Message.create({
        fromUserId: socket.userId,
        toUserId,
        text: text.trim(),
      });

      const populated = await Message.findById(message._id)
        .populate('fromUserId', 'username profilePic isPrivate')
        .populate('toUserId', 'username profilePic isPrivate');

      const roomId = getRoomId(socket.userId, toUserId);
      io.to(roomId).emit('new_message', populated);
      callback?.({ ok: true, message: populated });
    } catch (error) {
      callback?.({ ok: false, error: 'Failed to send message' });
    }
  });

  socket.on('disconnect', () => {
    onlineUsers.delete(socket.userId);
  });
});

// Database connection
console.log('Connecting to MongoDB...');
mongoose.connect(process.env.MONGO_URI, {
  serverSelectionTimeoutMS: 15000, // Wait 15s instead of 5s
  socketTimeoutMS: 45000,         // Don't close connection during long uploads
  family: 4                       // Use IPv4 to avoid DNS lag
})
  .then(() => console.log('✅ MongoDB Connected Successfully'))
  .catch(err => {
    console.error('❌ MongoDB Connection Error:');
    console.error(err.message);
  });

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.warn(`⚠️ Port ${currentPort} is already in use. Trying ${currentPort + 1}...`);
    currentPort += 1;
    server.listen(currentPort, '0.0.0.0');
    return;
  }

  throw error;
});

server.listen(currentPort, '0.0.0.0', () => {
  console.log(`🚀 Server is running on port ${currentPort}`);
});
