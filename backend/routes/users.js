const express = require('express');
const router = express.Router();
const multer = require('multer');
const auth = require('../middleware/auth');
const {
	getProfile,
	updateProfile,
	toggleFollow,
	searchUsers,
	togglePrivacy,
	getSuggestedUsers,
	toggleRepost,
	getReposts,
	uploadProfileImage,
	saveDeviceToken,
	deleteAccount,
} = require('../controllers/userController');

const storage = multer.memoryStorage();
const upload = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 } });

router.get('/search', searchUsers);
router.get('/suggested', getSuggestedUsers);
router.get('/:id/reposts', getReposts);
router.get('/:id', getProfile);
router.put('/update', auth, updateProfile);
router.post('/device-token', auth, saveDeviceToken);
router.post('/upload-profile-pic', auth, upload.single('image'), uploadProfileImage);
router.put('/follow/:id', auth, toggleFollow);
router.put('/privacy', auth, togglePrivacy);
router.put('/repost/:id', auth, toggleRepost);
router.delete('/delete-account', auth, deleteAccount);

module.exports = router;
