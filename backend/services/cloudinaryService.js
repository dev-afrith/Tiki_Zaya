const crypto = require('crypto');

const CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME;
const API_KEY = process.env.CLOUDINARY_API_KEY;
const API_SECRET = process.env.CLOUDINARY_API_SECRET;

/**
 * Generate signed upload parameters for direct client-to-Cloudinary upload.
 * The API secret never leaves the server — only the signature + public params
 * are sent to the client.
 *
 * @param {object} opts
 * @param {string} [opts.folder]        - Cloudinary folder (default: 'tikizaya')
 * @param {number} [opts.maxFileSize]   - Max bytes (default: 100 MB)
 * @param {number} [opts.ttlSeconds]    - Signature validity (default: 600 = 10 min)
 * @returns {{ apiKey, cloudName, signature, timestamp, folder, uploadUrl }}
 */
exports.generateSignedUploadParams = (opts = {}) => {
  const folder = opts.folder || 'tikizaya';
  const ttlSeconds = opts.ttlSeconds || 600;
  const timestamp = Math.floor(Date.now() / 1000);

  // Params that are signed must be sorted alphabetically.
  const paramsToSign = {
    folder,
    timestamp,
  };

  // Build the string-to-sign: key=value pairs joined by '&', then append secret.
  const sortedKeys = Object.keys(paramsToSign).sort();
  const signatureBase = sortedKeys
    .map((key) => `${key}=${paramsToSign[key]}`)
    .join('&');

  const signature = crypto
    .createHash('sha1')
    .update(signatureBase + API_SECRET)
    .digest('hex');

  return {
    apiKey: API_KEY,
    cloudName: CLOUD_NAME,
    signature,
    timestamp,
    folder,
    expiresAt: timestamp + ttlSeconds,
    uploadUrl: `https://api.cloudinary.com/v1_1/${CLOUD_NAME}/video/upload`,
  };
};

/**
 * Validate that a URL actually belongs to our Cloudinary account.
 * Prevents users from registering arbitrary URLs.
 */
exports.isValidCloudinaryUrl = (url) => {
  if (!url || typeof url !== 'string') return false;
  try {
    const parsed = new URL(url);
    return (
      parsed.protocol === 'https:' &&
      parsed.hostname === 'res.cloudinary.com' &&
      parsed.pathname.includes(`/${CLOUD_NAME}/`)
    );
  } catch {
    return false;
  }
};
