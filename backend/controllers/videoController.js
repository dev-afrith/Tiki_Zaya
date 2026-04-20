const Video = require('../models/Video');
const mongoose = require('mongoose');
const cloudinary = require('cloudinary').v2;
const User = require('../models/User');
const { createAndEmitNotification } = require('../utils/notifications');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

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

    // Upload to Cloudinary
    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { resource_type: 'video', folder: 'tikizaya' },
        (error, result) => {
          if (error) {
            console.error('[DEBUG] Cloudinary Error:', error);
            reject(error);
          } else {
            console.log('[DEBUG] Cloudinary Success!');
            resolve(result);
          }
        }
      );
      stream.end(req.file.buffer);
    });

    console.log('[DEBUG] Saving video metadata to MongoDB...');
    
    // Ensure connection is still alive after long upload
    if (mongoose.connection.readyState !== 1) {
      console.log('[DEBUG] Mongoose disconnected. Reconnecting...');
      await mongoose.connect(process.env.MONGO_URI);
    }

    const { caption, hashtags, mentions, thumbnailUrl, editingMetadata, videoDurationSeconds } = req.body;

    const parsedDuration = Number(videoDurationSeconds);
    if (Number.isFinite(parsedDuration) && parsedDuration > 60) {
      return res.status(400).json({ message: 'Video must be 60 seconds or less' });
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

    const author = await User.findById(req.userId).select('username followers');
    if (author && Array.isArray(author.followers) && author.followers.length > 0) {
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

    console.log('[DEBUG] Video saved to MongoDB successfully!');
    res.status(201).json({ message: 'Video uploaded successfully', video });
  } catch (error) {
    console.error('[DEBUG] Global Upload Error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Get feed videos (paginated with Smart Ranking)
exports.getFeed = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const videos = await Video.aggregate([
      { $match: { isArchived: { $ne: true } } },
      // 1. Calculate weighted scores
      {
        $addFields: {
          likesCount: { $size: "$likes" },
          favoritesCount: { $size: "$favorites" },
          viewsCount: { $ifNull: ["$viewsCount", "$views"] },
          // Time factor: closer to 0 means newer
          hoursSinceUpload: {
            $divide: [
              { $subtract: [new Date(), "$createdAt"] },
              3600000 // ms to hours
            ]
          }
        }
      },
      {
        $addFields: {
          // Smart Score: Higher is better. 
          // Popularity weight + freshness boost
          recommendationScore: {
            $divide: [
              { $add: [{ $multiply: ["$likesCount", 2] }, { $multiply: ["$favoritesCount", 3] }, 1] },
              { $add: ["$hoursSinceUpload", 1] } 
            ]
          }
        }
      },
      // 2. Sort by the calculated score
      { $sort: { recommendationScore: -1 } },
      { $skip: skip },
      { $limit: limit },
      // 3. Populate user data
      {
        $lookup: {
          from: 'users',
          localField: 'userId',
          foreignField: '_id',
          as: 'userId'
        }
      },
      { $unwind: '$userId' },
      // 4. Project and clean
      {
        $project: {
          'userId.email': 0,
          'userId.phone': 0,
          'userId.isPrivate': 0,
          'userId.followers': 0,
          'userId.following': 0,
          'userId.updatedAt': 0
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

    const total = await Video.countDocuments();

    res.status(200).json({
      videos: optimizedVideos,
      currentPage: page,
      totalPages: Math.ceil(total / limit),
      totalVideos: total,
    });
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
    const video = await Video.findById(req.params.id);
    if (!video) return res.status(404).json({ message: 'Video not found' });

    const actor = await User.findById(req.userId).select('username profilePic');

    const index = video.likes.indexOf(req.userId);
    if (index === -1) {
      video.likes.push(req.userId);
    } else {
      video.likes.splice(index, 1);
    }
    video.likesCount = video.likes.length;
    await video.save();

    if (index === -1 && actor) {
      await createAndEmitNotification(req.app.get('io'), {
        userId: video.userId,
        actorUserId: req.userId,
        type: 'like',
        title: 'New like',
        body: `${actor.username || 'Someone'} liked your reel`,
        entityType: 'video',
        entityId: video._id,
      });
    }

    res.status(200).json({ likes: video.likes.length, likesCount: video.likes.length, liked: index === -1 });
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
      { new: true }
    );
    if (!video) return res.status(404).json({ message: 'Video not found' });
    res.status(200).json({ sharesCount: video.sharesCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get discovery page data (trending tags, suggested users, top videos)
exports.getDiscoveryData = async (req, res) => {
  try {
    const User = require('../models/User');

    // 1. Get Trending Hashtags (Agregated from all video hashtags)
    const trendingTags = await Video.aggregate([
      { $match: { isArchived: { $ne: true } } },
      { $unwind: "$hashtags" },
      { $group: { _id: "$hashtags", count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);

    // 2. Get Recommended Creators (Top followed users)
    const recommendedCreators = await User.aggregate([
      { $addFields: { followersCount: { $size: "$followers" } } },
      { $sort: { followersCount: -1 } },
      { $limit: 5 },
      { $project: { username: 1, profilePic: 1, followersCount: 1, bio: 1 } }
    ]);

    // 3. Get Trending Videos (Highest views)
    const trendingVideos = await Video.find()
      .where('isArchived').ne(true)
      .sort({ views: -1 })
      .limit(9)
      .populate('userId', 'username profilePic');

    res.status(200).json({
      hashtags: trendingTags.map(t => `#${t._id}`),
      creators: recommendedCreators,
      videos: trendingVideos
    });
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

    return res.status(200).json({ ok: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
