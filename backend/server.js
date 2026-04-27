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
const { startBirthdayScheduler } = require('./utils/birthdayScheduler');
const { initStreakScheduler } = require('./utils/streakScheduler');

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
const streakRoutes = require('./routes/streaks');

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
app.use('/api/streaks', streakRoutes);

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

  // Mark messages as seen — called when user opens a conversation
  socket.on('mark_seen', async ({ fromUserId }) => {
    try {
      if (!fromUserId || typeof fromUserId !== 'string') return;

      const result = await Message.updateMany(
        {
          fromUserId: fromUserId,
          toUserId: socket.userId,
          readAt: null,
        },
        { $set: { readAt: new Date(), status: 'seen' } }
      );

      if (result.modifiedCount > 0) {
        // Notify the sender that their messages were seen
        const roomId = getRoomId(socket.userId, fromUserId);
        io.to(roomId).emit('messages_seen', {
          seenBy: socket.userId,
          seenAt: new Date().toISOString(),
        });
      }
    } catch (error) {
      console.error('mark_seen error:', error.message);
    }
  });

  // Typing indicator
  socket.on('typing', ({ toUserId, isTyping }) => {
    if (!toUserId || typeof toUserId !== 'string') return;
    const roomId = getRoomId(socket.userId, toUserId);
    socket.to(roomId).emit('user_typing', {
      userId: socket.userId,
      isTyping: !!isTyping,
    });
  });

  // Check if a user is online
  socket.on('check_online', ({ userId }, callback) => {
    if (!userId) return callback?.({ online: false });
    callback?.({ online: onlineUsers.has(userId) });
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
