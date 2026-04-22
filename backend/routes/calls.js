const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const callController = require('../controllers/callController');

router.post('/initiate', auth, callController.initiateCall);
router.post('/action', auth, callController.handleCallAction);

module.exports = router;
