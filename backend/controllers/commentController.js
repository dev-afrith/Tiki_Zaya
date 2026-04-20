const Comment = require('../models/Comment');
const Video = require('../models/Video');
const User = require('../models/User');
const { createAndEmitNotification } = require('../utils/notifications');

// Add comment
exports.addComment = async (req, res) => {
  try {
    const comment = new Comment({
      userId: req.userId,
      videoId: req.params.videoId,
      text: req.body.text,
      parentCommentId: req.body.parentCommentId || null,
    });
    await comment.save();

    const video = await Video.findByIdAndUpdate(req.params.videoId, { $inc: { commentsCount: 1 } }, { new: true });

    const actor = await User.findById(req.userId).select('username');
    if (video && actor) {
      await createAndEmitNotification(req.app.get('io'), {
        userId: video.userId,
        actorUserId: req.userId,
        type: 'comment',
        title: 'New comment',
        body: `${actor.username || 'Someone'} commented on your reel`,
        entityType: 'video',
        entityId: video._id,
      });
    }

    if (comment.parentCommentId) {
      await Comment.findByIdAndUpdate(comment.parentCommentId, { $inc: { replyCount: 1 } });
    }

    const populated = await comment.populate('userId', 'username profilePic');
    res.status(201).json(populated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Get comments for a video
exports.getComments = async (req, res) => {
  try {
    const rootComments = await Comment.find({ videoId: req.params.videoId, parentCommentId: null })
      .populate('userId', 'username profilePic')
      .sort({ createdAt: -1 });

    const replies = await Comment.find({ videoId: req.params.videoId, parentCommentId: { $ne: null } })
      .populate('userId', 'username profilePic')
      .sort({ createdAt: 1 });

    const groupedReplies = replies.reduce((acc, reply) => {
      const parentId = reply.parentCommentId.toString();
      if (!acc[parentId]) acc[parentId] = [];
      acc[parentId].push(reply);
      return acc;
    }, {});

    const comments = rootComments.map((comment) => ({
      ...comment.toObject(),
      replies: groupedReplies[comment._id.toString()] || [],
    }));

    res.status(200).json(comments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.toggleLikeComment = async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });

    const index = comment.likes.indexOf(req.userId);
    if (index === -1) {
      comment.likes.push(req.userId);
    } else {
      comment.likes.splice(index, 1);
    }
    await comment.save();

    res.status(200).json({ liked: index === -1, likesCount: comment.likes.length });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.deleteComment = async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });

    const video = await Video.findById(comment.videoId);
    if (!video) return res.status(404).json({ message: 'Video not found' });

    const isCommentOwner = comment.userId.toString() === req.userId.toString();
    const isVideoOwner = video.userId.toString() === req.userId.toString();
    if (!isCommentOwner && !isVideoOwner) {
      return res.status(403).json({ message: 'Not allowed to delete this comment' });
    }

    if (comment.parentCommentId) {
      await Comment.findByIdAndDelete(comment._id);
      await Comment.findByIdAndUpdate(comment.parentCommentId, { $inc: { replyCount: -1 } });
      video.commentsCount = Math.max(0, (video.commentsCount || 0) - 1);
      await video.save();
      return res.status(200).json({ ok: true, deletedCount: 1 });
    }

    const replyCount = await Comment.countDocuments({ parentCommentId: comment._id });
    await Comment.deleteMany({ $or: [{ _id: comment._id }, { parentCommentId: comment._id }] });

    const totalDeleted = 1 + replyCount;
    video.commentsCount = Math.max(0, (video.commentsCount || 0) - totalDeleted);
    await video.save();

    return res.status(200).json({ ok: true, deletedCount: totalDeleted });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
