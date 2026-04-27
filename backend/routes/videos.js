const express = require('express');
const router = express.Router();
const multer = require('multer');
const auth = require('../middleware/auth');
const {
	signUpload,
	registerUpload,
	uploadVideo,
	getFeed,
	getVideoById,
	getUserVideos,
	toggleLike,
	toggleFavorite,
	incrementView,
	incrementShare,
	getDiscoveryData,
	searchHashtagsAndVideos,
	getVideoStats,
	archiveVideo,
	unarchiveVideo,
	getArchivedVideos,
	deleteVideo,
} = require('../controllers/videoController');

const os = require('os');
const path = require('path');
const fs = require('fs');

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const tmpDir = path.join(os.tmpdir(), 'tikizaya-uploads');
    if (!fs.existsSync(tmpDir)) {
      fs.mkdirSync(tmpDir, { recursive: true });
    }
    cb(null, tmpDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname || ''));
  }
});
const upload = multer({ storage, limits: { fileSize: 100 * 1024 * 1024 } }); // 100MB limit

// ─── Direct upload (new fast path) ───
router.post('/sign-upload', auth, signUpload);
router.post('/register', auth, registerUpload);

// ─── Legacy upload (kept for backward compat) ───
router.post('/upload', auth, upload.single('video'), uploadVideo);

router.get('/feed', getFeed);
router.get('/single/:id', getVideoById);
router.get('/discovery', getDiscoveryData);
router.get('/search', searchHashtagsAndVideos);
router.get('/stats/:id', getVideoStats);
router.get('/user/:userId', auth, getUserVideos);
router.get('/archived/me', auth, getArchivedVideos);
router.put('/like/:id', auth, toggleLike);
router.put('/favorite/:id', auth, toggleFavorite);
router.put('/view/:id', incrementView);
router.put('/share/:id', incrementShare);
router.put('/archive/:id', auth, archiveVideo);
router.put('/unarchive/:id', auth, unarchiveVideo);
router.delete('/:id', auth, deleteVideo);

module.exports = router;

