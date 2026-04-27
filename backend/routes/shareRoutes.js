const express = require('express');
const router = express.Router();
const Video = require('../models/Video');
const User = require('../models/User');

router.get('/:videoId', async (req, res) => {
  try {
    const videoId = req.params.videoId;
    
    // Validate videoId format (mongoose ObjectId)
    if (!videoId || videoId.length !== 24) {
      return res.status(404).send(getFallbackHtml('Video not found'));
    }

    const video = await Video.findById(videoId);
    if (!video) {
      return res.status(404).send(getFallbackHtml('Video not found'));
    }

    const user = await User.findById(video.userId);
    const username = user ? user.username : 'user';
    const caption = video.caption || video.description || `Check out this amazing video by @${username}!`;

    // Generate Cloudinary Thumbnail URL
    let thumbnailUrl = video.thumbnailUrl;
    if (!thumbnailUrl && video.videoUrl) {
      if (video.videoUrl.includes('cloudinary.com') && video.videoUrl.includes('/upload/')) {
        thumbnailUrl = video.videoUrl.replace('/upload/', '/upload/so_1,q_auto,f_jpg/');
      } else {
        thumbnailUrl = video.videoUrl.replace('.mp4', '.jpg');
      }
    }

    // HTML Template with Open Graph Tags
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Watch @${username} on TikiZaya</title>
    
    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="video.other" />
    <meta property="og:title" content="Watch @${username} on TikiZaya" />
    <meta property="og:description" content="${caption}" />
    <meta property="og:image" content="${thumbnailUrl}" />
    <meta property="og:video" content="${video.videoUrl}" />
    <meta property="og:url" content="https://tikizaya.com/v/${videoId}" />
    
    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="Watch @${username} on TikiZaya" />
    <meta name="twitter:description" content="${caption}" />
    <meta name="twitter:image" content="${thumbnailUrl}" />
    <meta name="twitter:player" content="${video.videoUrl}" />

    <style>
      body {
        margin: 0;
        padding: 0;
        background-color: #0f0f12;
        color: white;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
      }
      .container {
        max-width: 400px;
        width: 100%;
        text-align: center;
        padding: 20px;
        box-sizing: border-box;
      }
      .thumbnail-container {
        position: relative;
        width: 100%;
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 10px 30px rgba(255, 0, 110, 0.2);
        margin-bottom: 20px;
        background-color: #1a1a2e;
        aspect-ratio: 9 / 16;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .thumbnail {
        width: 100%;
        height: 100%;
        object-fit: cover;
      }
      .play-btn {
        position: absolute;
        width: 60px;
        height: 60px;
        background-color: rgba(0,0,0,0.5);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        border: 2px solid white;
      }
      .play-btn::after {
        content: '';
        border-top: 10px solid transparent;
        border-bottom: 10px solid transparent;
        border-left: 16px solid white;
        margin-left: 6px;
      }
      .title {
        font-size: 20px;
        font-weight: bold;
        margin-bottom: 8px;
      }
      .caption {
        font-size: 14px;
        color: #aaaaaa;
        margin-bottom: 30px;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }
      .btn {
        background: linear-gradient(135deg, #FF006E, #B067FF);
        color: white;
        text-decoration: none;
        padding: 14px 30px;
        border-radius: 30px;
        font-weight: bold;
        font-size: 16px;
        display: inline-block;
        box-shadow: 0 4px 15px rgba(255, 0, 110, 0.3);
      }
    </style>
</head>
<body>
    <div class="container">
        <div class="thumbnail-container">
            <img src="${thumbnailUrl}" class="thumbnail" alt="Video Thumbnail">
            <div class="play-btn"></div>
        </div>
        <div class="title">@${username}</div>
        <div class="caption">${caption}</div>
        <a href="intent://tikizaya.com/v/${videoId}#Intent;scheme=https;package=com.afrith.tikizaya;end" class="btn">Open in App</a>
    </div>
</body>
</html>
    `;
    
    res.send(html);
  } catch (error) {
    console.error('Share Route Error:', error);
    res.status(500).send(getFallbackHtml('Something went wrong'));
  }
});

function getFallbackHtml(message) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TikiZaya - ${message}</title>
    <style>
      body {
        margin: 0;
        background-color: #0f0f12;
        color: white;
        font-family: sans-serif;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100vh;
      }
      .btn {
        background: #FF006E;
        color: white;
        text-decoration: none;
        padding: 12px 24px;
        border-radius: 24px;
        margin-top: 20px;
        font-weight: bold;
      }
    </style>
</head>
<body>
    <h2>${message}</h2>
    <a href="https://play.google.com/store/apps/details?id=com.afrith.tikizaya" class="btn">Download TikiZaya</a>
</body>
</html>
  `;
}

module.exports = router;
