const { RtcTokenBuilder, RtcRole } = require('agora-token');

const generateRtcToken = (channelName, uid, role = 'publisher', expiryInSeconds = 300) => {
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  if (!appId || !appCertificate) {
    throw new Error('AGORA_APP_ID or AGORA_APP_CERTIFICATE is not defined in environment variables');
  }

  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expiryInSeconds;

  const agoraRole = role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

  console.log(`Generating token for Channel: ${channelName}, User: ${uid}, Role: ${role}`);

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    agoraRole,
    privilegeExpiredTs
  );

  return token;
};

module.exports = {
  generateRtcToken,
};
