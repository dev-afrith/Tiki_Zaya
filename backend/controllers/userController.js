const User = require('../models/User');
const Video = require('../models/Video');
const Comment = require('../models/Comment');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Get user profile
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Update or Create user profile (Upsert)
exports.updateProfile = async (req, res) => {
  try {
    const {
      username,
      name,
      bio,
      profilePic,
      profilePhotoUrl,
      isPrivate,
      email,
      phone,
      country,
      dateOfBirth,
      category,
      socialLinks,
      themePreference,
    } = req.body;

    const currentUser = await User.findById(req.userId);
    const normalizedUsername = (username ?? '').toString().trim().toLowerCase();
    
    // Username is immutable once set.
    if (currentUser?.username && normalizedUsername && normalizedUsername != currentUser.username) {
      return res.status(400).json({ message: 'Username cannot be changed after account creation' });
    }

    // Check if username is taken by another user when first-time set.
    if (normalizedUsername) {
      const existingUser = await User.findOne({ username: normalizedUsername, _id: { $ne: req.userId } });
      if (existingUser) {
        return res.status(400).json({ message: 'Username is already taken' });
      }
    }

    const normalizedBio = bio == null ? null : bio.toString().trim();
    if (normalizedBio != null && normalizedBio.length > 200) {
      return res.status(400).json({ message: 'Bio must be 200 characters or fewer' });
    }

    const normalizedName = name == null ? null : name.toString().trim();
    if (normalizedName != null && normalizedName.length > 60) {
      return res.status(400).json({ message: 'Name must be 60 characters or fewer' });
    }

    const normalizeUrl = (value) => (value == null ? '' : value.toString().trim());
    const isValidUrl = (value) => {
      if (!value) return true;
      try {
        const url = new URL(value);
        return url.protocol === 'http:' || url.protocol === 'https:';
      } catch (_) {
        return false;
      }
    };

    const normalizedSocialLinks = {
      instagram: normalizeUrl(socialLinks?.instagram),
      youtube: normalizeUrl(socialLinks?.youtube),
      website: normalizeUrl(socialLinks?.website),
    };
    if (!isValidUrl(normalizedSocialLinks.instagram) || !isValidUrl(normalizedSocialLinks.youtube) || !isValidUrl(normalizedSocialLinks.website)) {
      return res.status(400).json({ message: 'Social links must be valid URLs (http/https)' });
    }

    let parsedDateOfBirth;
    if (dateOfBirth != null && dateOfBirth.toString().trim() !== '') {
      parsedDateOfBirth = new Date(dateOfBirth);
      if (isNaN(parsedDateOfBirth.getTime())) {
        return res.status(400).json({ message: 'Invalid date of birth' });
      }
      const minBirthDate = new Date();
      minBirthDate.setFullYear(minBirthDate.getFullYear() - 13);
      if (parsedDateOfBirth > minBirthDate) {
        return res.status(400).json({ message: 'You must be at least 13 years old' });
      }
    }

    // Limit display name changes to 2 per rolling 7-day window.
    let nextNameHistory = (currentUser?.nameChangeHistory || []).map((d) => new Date(d));
    if (normalizedName != null && normalizedName != (currentUser?.name || '')) {
      const sevenDaysAgo = new Date(Date.now() - (7 * 24 * 60 * 60 * 1000));
      nextNameHistory = nextNameHistory.filter((d) => d >= sevenDaysAgo);
      if (nextNameHistory.length >= 2) {
        return res.status(400).json({ message: 'You can only change your name 2 times per week' });
      }
      nextNameHistory.push(new Date());
    }

    if (themePreference != null && !['light', 'dark'].includes(themePreference)) {
      return res.status(400).json({ message: 'Invalid theme preference' });
    }

    const updateData = { _id: req.userId }; // Ensure _id is set for upsert
    if (normalizedUsername) updateData.username = normalizedUsername;
    if (normalizedName !== null) updateData.name = normalizedName;
    if (normalizedBio !== null) updateData.bio = normalizedBio;
    if (profilePic !== undefined) updateData.profilePic = profilePic;
    if (profilePhotoUrl !== undefined) updateData.profilePhotoUrl = profilePhotoUrl;
    if (isPrivate !== undefined) updateData.isPrivate = isPrivate;
    if (email) updateData.email = email;
    if (phone) updateData.phone = phone;
    if (country !== undefined) updateData.country = country;
    if (parsedDateOfBirth !== undefined) updateData.dateOfBirth = parsedDateOfBirth;
    if (category !== undefined) updateData.category = category;
    if (socialLinks !== undefined) updateData.socialLinks = normalizedSocialLinks;
    if (themePreference !== undefined) updateData.themePreference = themePreference;
    if (!currentUser?.role) updateData.role = 'user';
    if (!currentUser?.status) updateData.status = 'active';
    if (normalizedName != null && normalizedName != (currentUser?.name || '')) {
      updateData.nameChangeHistory = nextNameHistory;
    }

    // Keep both fields in sync for backward compatibility.
    if (updateData.profilePic !== undefined && updateData.profilePhotoUrl === undefined) {
      updateData.profilePhotoUrl = updateData.profilePic;
    }
    if (updateData.profilePhotoUrl !== undefined && updateData.profilePic === undefined) {
      updateData.profilePic = updateData.profilePhotoUrl;
    }

    const user = await User.findByIdAndUpdate(
      req.userId,
      { $set: updateData },
      { new: true, runValidators: true, upsert: true }
    );

    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Toggle Account Privacy
exports.togglePrivacy = async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    user.isPrivate = !user.isPrivate;
    await user.save();
    res.status(200).json({ isPrivate: user.isPrivate });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Follow / Unfollow user
exports.toggleFollow = async (req, res) => {
  try {
    const targetUser = await User.findById(req.params.id);
    const currentUser = await User.findById(req.userId);

    if (!targetUser || !currentUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    const isFollowing = currentUser.following.includes(req.params.id);

    if (isFollowing) {
      currentUser.following.pull(req.params.id);
      targetUser.followers.pull(req.userId);
    } else {
      currentUser.following.push(req.params.id);
      targetUser.followers.push(req.userId);
    }

    await currentUser.save();
    await targetUser.save();

    res.status(200).json({
      following: !isFollowing,
      followersCount: targetUser.followers.length,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get suggested users (for Stories section)
exports.getSuggestedUsers = async (req, res) => {
  try {
    const users = await User.find({ username: { $exists: true, $ne: null } })
      .sort({ createdAt: -1 })
      .limit(15)
      .select('username profilePic bio');
    res.status(200).json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Search users
exports.searchUsers = async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ message: 'Search query required' });

    const users = await User.find({
      $or: [
        { username: { $regex: query, $options: 'i' } },
        { bio: { $regex: query, $options: 'i' } },
      ],
    }).select('username profilePic bio followers following');

    res.status(200).json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Toggle repost for a video
exports.toggleRepost = async (req, res) => {
  try {
    const videoId = req.params.id;
    const user = await User.findById(req.userId);
    const video = await Video.findById(videoId);

    if (!user || !video) {
      return res.status(404).json({ message: 'User or video not found' });
    }

    const repostIndex = (user.reposts || []).findIndex((item) => item.toString() === videoId);
    let reposted = false;

    if (repostIndex === -1) {
      user.reposts.push(videoId);
      video.repostsCount = (video.repostsCount || 0) + 1;
      reposted = true;
    } else {
      user.reposts.splice(repostIndex, 1);
      video.repostsCount = Math.max(0, (video.repostsCount || 0) - 1);
    }

    await user.save();
    await video.save();

    res.status(200).json({ reposted, repostsCount: video.repostsCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get reposted videos for a user
exports.getReposts = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const videos = await Video.find({ _id: { $in: user.reposts || [] } })
      .sort({ createdAt: -1 })
      .populate('userId', 'username profilePic isPrivate country createdAt');

    res.status(200).json(videos);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.uploadProfileImage = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No image file provided' });
    }

    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { resource_type: 'image', folder: 'tikizaya/profiles' },
        (error, uploadResult) => {
          if (error) reject(error);
          else resolve(uploadResult);
        }
      );
      stream.end(req.file.buffer);
    });

    const user = await User.findByIdAndUpdate(
      req.userId,
      { $set: { profilePic: result.secure_url, profilePhotoUrl: result.secure_url } },
      { new: true, upsert: true }
    );

    return res.status(200).json({ profilePic: result.secure_url, user });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.deleteAccount = async (req, res) => {
  try {
    const userId = req.userId;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const ownedVideos = await Video.find({ userId }).select('_id');
    const ownedVideoIds = ownedVideos.map((v) => v._id);

    await Comment.deleteMany({
      $or: [
        { userId },
        { videoId: { $in: ownedVideoIds } },
      ],
    });

    await Video.deleteMany({ userId });

    await Message.deleteMany({
      $or: [
        { fromUserId: userId },
        { toUserId: userId },
      ],
    });

    await Notification.deleteMany({
      $or: [
        { userId },
        { actorUserId: userId },
      ],
    });

    await User.updateMany(
      { _id: { $ne: userId } },
      {
        $pull: {
          followers: userId,
          following: userId,
          reposts: { $in: ownedVideoIds },
        },
      }
    );

    await User.findByIdAndDelete(userId);

    return res.status(200).json({ ok: true, message: 'Account deleted permanently' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
