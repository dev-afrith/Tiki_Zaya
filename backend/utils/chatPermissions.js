const canSendMessage = ({ sender, recipient }) => {
  if (!sender || !recipient) return false;
  if (sender._id === recipient._id) return true;

  if (!recipient.isPrivate) {
    return true;
  }

  const senderFollowsRecipient = (sender.following || []).includes(recipient._id);
  const recipientFollowsSender = (recipient.following || []).includes(sender._id);

  return senderFollowsRecipient && recipientFollowsSender;
};

module.exports = { canSendMessage };
