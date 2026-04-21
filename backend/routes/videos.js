const express = require('express');
const router = express.Router();
const multer = require('multer');
const auth = require('../middleware/auth');
const {
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

const storage = multer.memoryStorage();
const upload = multer({ storage, limits: { fileSize: 100 * 1024 * 1024 } }); // 100MB limit

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
