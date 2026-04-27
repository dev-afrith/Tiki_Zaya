const Video = require('../models/Video');
const mongoose = require('mongoose');
const cloudinary = require('cloudinary').v2;
const User = require('../models/User');
const { createAndEmitNotification } = require('../utils/notifications');
const { buildGamificationSummary, ensureGamificationState } = require('../utils/gamification');
const { generateSignedUploadParams, isValidCloudinaryUrl } = require('../services/cloudinaryService');
const notificationQueue = require('../services/notificationQueue');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ─── DIRECT UPLOAD: Step 1 — Generate signed params ─────────────
exports.signUpload = async (req, res) => {
  try {
    const params = generateSignedUploadParams({ folder: 'tikizaya' });
    return res.status(200).json(params);
  } catch (error) {
    console.error('[SIGN UPLOAD ERROR]', error.message);
    return res.status(500).json({ message: 'Failed to generate upload signature' });
  }
};

// ─── DIRECT UPLOAD: Step 2 — Register video after client upload ──
exports.registerUpload = async (req, res) => {
  try {
    const { videoUrl, caption, hashtags, mentions, thumbnailUrl, editingMetadata, videoDurationSeconds } = req.body;

    if (!videoUrl || !isValidCloudinaryUrl(videoUrl)) {
      return res.status(400).json({ message: 'Invalid or missing Cloudinary video URL' });
    }

    const parsedDuration = Number(videoDurationSeconds);
    if (Number.isFinite(parsedDuration) && parsedDuration > 90) {
      return res.status(400).json({ message: 'Video must be 90 seconds or less' });
    }

    const processArray = (input) => {
      if (!input) return [];
      if (Array.isArray(input)) return input;
      return input.split(',').map(s => s.trim()).filter(s => s.length > 0);
    };

    let parsedMetadata = {};
    if (editingMetadata) {
      try {
        parsedMetadata = typeof editingMetadata === 'string' ? JSON.parse(editingMetadata) : editingMetadata;
      } catch (e) {
        console.warn('Failed to parse editingMetadata:', e);
      }
    }

    const video = new Video({
      userId: req.userId,
      videoUrl,
      description: caption || '',
      caption: caption || '',
      hashtags: processArray(hashtags),
      mentions: processArray(mentions),
      thumbnailUrl: thumbnailUrl || '',
      editingMetadata: parsedMetadata,
      likesCount: 0,
      viewsCount: 0,
      views: 0,
      sharesCount: 0,
      commentsCount: 0,
      videoDurationSeconds: Number.isFinite(parsedDuration) ? parsedDuration : undefined,
    });

    await video.save();

    // Gamification
    const author = await User.findById(req.userId).select('username followers gamification');
    if (author) {
      const gamification = ensureGamificationState(author);
      gamification.uploadsTotal = Number(gamification.uploadsTotal || 0) + 1;
      await author.save();
      req.app.get('io')?.to(req.userId).emit('gamification_updated', {
        user: author,
        gamification: buildGamificationSummary(author),
      });
    }

    // Notify followers via background queue (instant API response)
    if (author && Array.isArray(author.followers) && author.followers.length > 0) {
      const queued = await notificationQueue.queueFollowerNotifications({
        authorId: req.userId,
        authorUsername: author.username || 'Someone',
        videoId: video._id.toString(),
        followerIds: author.followers.map(String),
      });

      // Fallback to inline if queue is unavailable
      if (!queued) {
        const io = req.app.get('io');
        for (const followerId of author.followers) {
          await createAndEmitNotification(io, {
            userId: followerId,
            actorUserId: req.userId,
            type: 'post',
            title: 'New post',
            body: `${author.username || 'Someone'} has posted a new video`,
            entityType: 'video',
            entityId: video._id,
          });
        }
      }
    }

    // Invalidate feed cache if Redis is available
    try {
      const redis = require('../services/redisService');
      if (redis.isReady()) await redis.invalidateFeedCache();
    } catch (_) {}

    console.log('[REGISTER UPLOAD] Video registered successfully');
    return res.status(201).json({ message: 'Video registered successfully', video });
  } catch (error) {
    console.error('[REGISTER UPLOAD ERROR]', error.message);
    return res.status(500).json({ error: error.message });
  }
};

// Upload video
exports.uploadVideo = async (req, res) => {
  try {
    console.log('[DEBUG] Starting video upload process...');
    if (!req.file) {
      console.log('[DEBUG] No file found in request');
      return res.status(400).json({ message: 'No video file provided' });
    }

    console.log(`[DEBUG] File size: ${(req.file.size / 1024 / 1024).toFixed(2)} MB`);
    console.log('[DEBUG] Uploading to Cloudinary...');

    // Upload to Cloudinary from local disk
    const result = await cloudinary.uploader.upload(req.file.path, {
      resource_type: 'video',
      folder: 'tikizaya'
    });
    console.log('[DEBUG] Cloudinary Success!');

    // Clean up temporary file
    const fs = require('fs');
    fs.unlink(req.file.path, (err) => {
      if (err) console.error('[DEBUG] Failed to delete temp file:', err);
    });

    console.log('[DEBUG] Saving video metadata to MongoDB...');
    
    // Ensure connection is still alive after long upload
    if (mongoose.connection.readyState !== 1) {
      console.log('[DEBUG] Mongoose disconnected. Reconnecting...');
      await mongoose.connect(process.env.MONGO_URI);
    }

    const { caption, hashtags, mentions, thumbnailUrl, editingMetadata, videoDurationSeconds } = req.body;

    const parsedDuration = Number(videoDurationSeconds);
    if (Number.isFinite(parsedDuration) && parsedDuration > 90) {
      return res.status(400).json({ message: 'Video must be 90 seconds or less' });
    }
    
    // Process hashtags and mentions (convert to arrays if strings)
    const processArray = (input) => {
      if (!input) return [];
      if (Array.isArray(input)) return input;
      return input.split(',').map(s => s.trim()).filter(s => s.length > 0);
    };

    // Parse editing metadata if sent as string
    let parsedMetadata = {};
    if (editingMetadata) {
      try {
        parsedMetadata = typeof editingMetadata === 'string' ? JSON.parse(editingMetadata) : editingMetadata;
      } catch (e) {
        console.warn('Failed to parse editingMetadata:', e);
      }
    }

    const video = new Video({
      userId: req.userId,
      videoUrl: result.secure_url,
      description: caption || '',
      caption: caption || '',
      hashtags: processArray(hashtags),
      mentions: processArray(mentions),
      thumbnailUrl: thumbnailUrl || '',
      editingMetadata: parsedMetadata,
      likesCount: 0,
      viewsCount: 0,
      views: 0,
      sharesCount: 0,
      commentsCount: 0,
      videoDurationSeconds: Number.isFinite(parsedDuration) ? parsedDuration : undefined,
    });

    await video.save();

    const author = await User.findById(req.userId).select('username followers gamification');
    if (author) {
      const gamification = ensureGamificationState(author);
      gamification.uploadsTotal = Number(gamification.uploadsTotal || 0) + 1;
      await author.save();
      req.app.get('io')?.to(req.userId).emit('gamification_updated', {
        user: author,
        gamification: buildGamificationSummary(author),
      });
    }
    // Notify followers via background queue
    if (author && Array.isArray(author.followers) && author.followers.length > 0) {
      const queued = await notificationQueue.queueFollowerNotifications({
        authorId: req.userId,
        authorUsername: author.username || 'Someone',
        videoId: video._id.toString(),
        followerIds: author.followers.map(String),
      });

      if (!queued) {
        const io = req.app.get('io');
        for (const followerId of author.followers) {
          await createAndEmitNotification(io, {
            userId: followerId,
            actorUserId: req.userId,
            type: 'post',
            title: 'New post',
            body: `${author.username || 'Someone'} has posted a new video`,
            entityType: 'video',
            entityId: video._id,
          });
        }
      }
    }

    console.log('[DEBUG] Video saved to MongoDB successfully!');
    res.status(201).json({ message: 'Video uploaded successfully', video });
  } catch (error) {
    console.error('[DEBUG] Global Upload Error:', error.message);
    if (req.file && req.file.path) {
      const fs = require('fs');
      fs.unlink(req.file.path, (err) => {
        if (err) console.error('[DEBUG] Failed to delete temp file in error block:', err);
      });
    }
    res.status(500).json({ error: error.message });
  }
};

// Get feed videos (paginated with Smart Ranking + Redis cache)
exports.getFeed = async (req, res) => {
  try {
    const redis = require('../services/redisService');
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const cacheKey = `feed:p${page}:l${limit}`;

    // ── Check Redis cache first ──
    if (redis.isReady()) {
      const cached = await redis.getJSON(cacheKey);
      if (cached) {
        return res.status(200).json(cached);
      }
    }

    const skip = (page - 1) * limit;

    const videos = await Video.aggregate([
      { $match: { isArchived: { $ne: true } } },
      {
        $addFields: {
          likesCount: { $size: "$likes" },
          favoritesCount: { $size: "$favorites" },
          viewsCount: { $ifNull: ["$viewsCount", "$views"] },
          hoursSinceUpload: {
            $divide: [
              { $subtract: [new Date(), "$createdAt"] },
              3600000
            ]
          }
        }
      },
      {
        $addFields: {
          recommendationScore: {
            $divide: [
              { $add: [{ $multiply: ["$likesCount", 2] }, { $multiply: ["$favoritesCount", 3] }, 1] },
              { $add: ["$hoursSinceUpload", 1] }
            ]
          }
        }
      },
      { $sort: { recommendationScore: -1 } },
      { $skip: skip },
      { $limit: limit },
      {
        $lookup: {
          from: 'users',
          localField: 'userId',
          foreignField: '_id',
          as: 'userId'
        }
      },
      { $unwind: '$userId' },
      {
        $project: {
          'userId.email': 0,
          'userId.phone': 0,
          'userId.isPrivate': 0,
          'userId.followers': 0,
          'userId.following': 0,
          'userId.updatedAt': 0,
          'userId.passwordHash': 0,
          'userId.refreshTokens': 0,
          'userId.passwordReset': 0,
          'userId.fcmTokens': 0,
        }
      }
    ]);

    // Add Cloudinary auto-optimization params
    const optimizedVideos = videos.map(video => {
      const v = { ...video };
      if (v.videoUrl && v.videoUrl.includes('cloudinary.com')) {
        v.videoUrl = v.videoUrl.replace('/upload/', '/upload/q_auto,f_auto/');
      }
      return v;
    });

    const total = await Video.countDocuments({ isArchived: { $ne: true } });

    const responseData = {
      videos: optimizedVideos,
      currentPage: page,
      totalPages: Math.ceil(total / limit),
      totalVideos: total,
    };

    // ── Cache the result (90 second TTL) ──
    if (redis.isReady()) {
      await redis.setJSON(cacheKey, responseData, 90);
    }

    res.status(200).json(responseData);
  } catch (error) {
    console.error('[FEED ERROR]', error);
    res.status(500).json({ error: error.message });
  }
};

// Get videos by user
exports.getUserVideos = async (req, res) => {
  try {
    const videos = await Video.find({ userId: req.params.userId, isArchived: { $ne: true } })
      .sort({ createdAt: -1 });
    res.status(200).json(videos);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Like / Unlike video
exports.toggleLike = async (req, res) => {
  try {
    const videoId = req.params.id;
    const userId = req.userId;

    const video = await Video.findById(videoId).select('likes userId');
    if (!video) return res.status(404).json({ message: 'Video not found' });

    const isLiked = video.likes.includes(userId);
    let updatedLikesCount;

    if (isLiked) {
      const updated = await Video.findByIdAndUpdate(
        videoId,
        { $pull: { likes: userId }, $inc: { likesCount: -1 } },
        { new: true, select: 'likesCount' }
      );
      updatedLikesCount = updated.likesCount;
    } else {
      const updated = await Video.findByIdAndUpdate(
        videoId,
        { $addToSet: { likes: userId }, $inc: { likesCount: 1 } },
        { new: true, select: 'likesCount' }
      );
      updatedLikesCount = updated.likesCount;

      // Offload notification to background to prevent blocking
      process.nextTick(async () => {
        try {
          const actor = await User.findById(userId).select('username');
          if (actor) {
            await createAndEmitNotification(req.app.get('io'), {
              userId: video.userId,
              actorUserId: userId,
              type: 'like',
              title: 'New like',
              body: `${actor.username || 'Someone'} liked your reel`,
              entityType: 'video',
              entityId: video._id,
            });
          }
        } catch (e) {
          console.error('Background notification error:', e);
        }
      });
    }

    res.status(200).json({ success: true, likesCount: updatedLikesCount, liked: !isLiked });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Favorite / Unfavorite video
exports.toggleFavorite = async (req, res) => {
  try {
    const video = await Video.findById(req.params.id);
    if (!video) return res.status(404).json({ message: 'Video not found' });

    const index = video.favorites.indexOf(req.userId);
    if (index === -1) {
      video.favorites.push(req.userId);
    } else {
      video.favorites.splice(index, 1);
    }
    await video.save();

    res.status(200).json({ favoritesCount: video.favorites.length, favorited: index === -1 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Increment video views
exports.incrementView = async (req, res) => {
  try {
    const video = await Video.findByIdAndUpdate(
      req.params.id,
      { $inc: { views: 1, viewsCount: 1 } },
      { new: true }
    );
    if (!video) return res.status(404).json({ message: 'Video not found' });
    res.status(200).json({ views: video.views, viewsCount: video.viewsCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Increment video shares
exports.incrementShare = async (req, res) => {
  try {
    const video = await Video.findByIdAndUpdate(
      req.params.id,
      { $inc: { sharesCount: 1 } },
      { new: true, select: 'sharesCount' }
    );
    if (!video) return res.status(404).json({ message: 'Video not found' });
    res.status(200).json({ success: true, sharesCount: video.sharesCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get discovery page data (trending tags, suggested users, top videos) + Redis cache
exports.getDiscoveryData = async (req, res) => {
  try {
    const redis = require('../services/redisService');

    // ── Check cache ──
    if (redis.isReady()) {
      const cached = await redis.getJSON('discovery');
      if (cached) return res.status(200).json(cached);
    }

    const User = require('../models/User');

    const trendingTags = await Video.aggregate([
      { $match: { isArchived: { $ne: true } } },
      { $unwind: "$hashtags" },
      { $group: { _id: "$hashtags", count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);

    const recommendedCreators = await User.aggregate([
      { $addFields: { followersCount: { $size: "$followers" } } },
      { $sort: { followersCount: -1 } },
      { $limit: 5 },
      { $project: { username: 1, profilePic: 1, followersCount: 1, bio: 1 } }
    ]);

    const trendingVideos = await Video.find()
      .where('isArchived').ne(true)
      .sort({ views: -1 })
      .limit(9)
      .populate('userId', 'username profilePic');

    const responseData = {
      hashtags: trendingTags.map(t => `#${t._id}`),
      creators: recommendedCreators,
      videos: trendingVideos
    };

    // ── Cache (120 second TTL) ──
    if (redis.isReady()) {
      await redis.setJSON('discovery', responseData, 120);
    }

    res.status(200).json(responseData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Search hashtags and related videos
exports.searchHashtagsAndVideos = async (req, res) => {
  try {
    const rawQuery = (req.query.query || '').toString().trim();
    if (!rawQuery) {
      return res.status(200).json({ hashtags: [], videos: [] });
    }

    const query = rawQuery.replace(/^#/, '').toLowerCase();
    const queryRegex = new RegExp(query, 'i');

    const hashtagAgg = await Video.aggregate([
      { $unwind: '$hashtags' },
      { $match: { hashtags: queryRegex } },
      { $group: { _id: '$hashtags', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 8 },
    ]);

    const relatedHashtags = hashtagAgg.map((h) => h._id.toString().toLowerCase());
    const videoQuery = {
      $or: [
        { caption: queryRegex },
        { hashtags: queryRegex },
        ...(relatedHashtags.length > 0 ? [{ hashtags: { $in: relatedHashtags } }] : []),
      ],
    };

    const videos = await Video.find(videoQuery)
      .where('isArchived').ne(true)
      .sort({ views: -1, createdAt: -1 })
      .limit(18)
      .populate('userId', 'username profilePic');

    return res.status(200).json({
      hashtags: hashtagAgg.map((h) => `#${h._id}`),
      videos,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getVideoById = async (req, res) => {
  try {
    const video = await Video.findById(req.params.id)
      .populate('userId', 'username profilePic isPrivate country createdAt');

    if (!video || video.isArchived === true) {
      return res.status(404).json({ message: 'Video not found' });
    }

    return res.status(200).json(video);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getVideoStats = async (req, res) => {
  try {
    const video = await Video.findById(req.params.id).select('repostsCount sharesCount likes commentsCount viewsCount views likesCount');
    if (!video) return res.status(404).json({ message: 'Video not found' });
    return res.status(200).json({
      repostsCount: video.repostsCount || 0,
      sharesCount: video.sharesCount || 0,
      likesCount: Array.isArray(video.likes) ? video.likes.length : 0,
      commentsCount: video.commentsCount || 0,
      viewsCount: video.viewsCount || video.views || 0,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.archiveVideo = async (req, res) => {
  try {
    const video = await Video.findById(req.params.id);
    if (!video) return res.status(404).json({ message: 'Video not found' });
    if (video.userId.toString() !== req.userId.toString()) {
      return res.status(403).json({ message: 'Not allowed to archive this video' });
    }

    video.isArchived = true;
    video.archivedAt = new Date();
    await video.save();

    // Invalidate feed cache
    try { const redis = require('../services/redisService'); if (redis.isReady()) await redis.invalidateFeedCache(); } catch (_) {}

    return res.status(200).json({ ok: true, isArchived: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.unarchiveVideo = async (req, res) => {
  try {
    const video = await Video.findById(req.params.id);
    if (!video) return res.status(404).json({ message: 'Video not found' });
    if (video.userId.toString() !== req.userId.toString()) {
      return res.status(403).json({ message: 'Not allowed to restore this video' });
    }

    video.isArchived = false;
    video.archivedAt = null;
    await video.save();

    return res.status(200).json({ ok: true, isArchived: false });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getArchivedVideos = async (req, res) => {
  try {
    const videos = await Video.find({ userId: req.userId, isArchived: true })
      .sort({ archivedAt: -1, createdAt: -1 });
    return res.status(200).json(videos);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.deleteVideo = async (req, res) => {
  try {
    const video = await Video.findById(req.params.id);
    if (!video) return res.status(404).json({ message: 'Video not found' });
    if (video.userId.toString() !== req.userId.toString()) {
      return res.status(403).json({ message: 'Not allowed to delete this video' });
    }

    await Video.findByIdAndDelete(req.params.id);
    const Comment = require('../models/Comment');
    await Comment.deleteMany({ videoId: req.params.id });

    // Invalidate feed cache
    try { const redis = require('../services/redisService'); if (redis.isReady()) await redis.invalidateFeedCache(); } catch (_) {}

    return res.status(200).json({ ok: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
