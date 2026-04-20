const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { addComment, getComments, toggleLikeComment, deleteComment } = require('../controllers/commentController');

router.post('/:videoId', auth, addComment);
router.get('/:videoId', getComments);
router.put('/like/:id', auth, toggleLikeComment);
router.delete('/:id', auth, deleteComment);

module.exports = router;
