const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const { Server } = require('socket.io');
const User = require('./models/User');
const Message = require('./models/Message');
const authMiddleware = require('./middleware/auth');
const { canSendMessage } = require('./utils/chatPermissions');
const { startBirthdayScheduler } = require('./utils/birthdayScheduler');

dotenv.config();

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 5001;

const allowedOrigins = (process.env.CLIENT_URL || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) {
      callback(null, true);
      return;
    }

    if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
};

const io = new Server(server, {
  cors: { ...corsOptions, methods: ['GET', 'POST'] },
});

app.set('io', io);

// Middleware
app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json());

// Global Request Logger
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const durationMs = Date.now() - start;
    const ts = new Date().toISOString();
    console.log('[' + ts + '] ' + req.method + ' ' + req.originalUrl + ' ' + res.statusCode + ' - ' + durationMs + 'ms');
  });
  next();
});

// Routes
const videoRoutes = require('./routes/videos');
const commentRoutes = require('./routes/comments');
const userRoutes = require('./routes/users');
const authRoutes = require('./routes/auth');
const gamificationRoutes = require('./routes/gamification');
const messageRoutes = require('./routes/messages');
const notificationRoutes = require('./routes/notifications');

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Tiki Zaya API is running!' });
});

app.get('/', (req, res) => {
  res.status(200).send('Tiki Zaya API is running 🚀');
});

app.use('/api/auth', authRoutes);
app.use('/api/videos', videoRoutes);
app.use('/api/comments', commentRoutes);
app.use('/api/users', userRoutes);
app.use('/api/gamification', gamificationRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/notifications', notificationRoutes);

app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

app.use((err, req, res, next) => {
  if (res.headersSent) {
    next(err);
    return;
  }

  if (err && err.message === 'Not allowed by CORS') {
    res.status(403).json({ message: 'CORS error: origin not allowed' });
    return;
  }

  console.error('Server error:', err);
  res.status(500).json({ message: 'Internal server error' });
});

const onlineUsers = new Map();

const getRoomId = (a, b) => [a, b].sort().join('__');

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('Missing auth token'));
    }

    const decoded = await authMiddleware.verifyAnyToken(token);
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

async function startServer() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI, {
      serverSelectionTimeoutMS: 15000,
      socketTimeoutMS: 45000,
      family: 4,
    });
    console.log('MongoDB connected');

    server.listen(PORT, () => {
      console.log('Server is running on port ' + PORT);
      startBirthdayScheduler(io);
    });
  } catch (err) {
    console.error('MongoDB connection failed:', err.message);
    process.exit(1);
  }
}

startServer();
