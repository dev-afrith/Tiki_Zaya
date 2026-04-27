import 'package:flutter/material.dart';

class ActionButtons extends StatefulWidget {
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onPrimaryTap;
  final VoidCallback onShareTap;

  const ActionButtons({
    super.key,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.onPrimaryTap,
    required this.onShareTap,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildPrimaryButton(),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _buildShareButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFollowAction = !widget.isOwnProfile && !widget.isFollowing;
    
    return InkWell(
      onTap: widget.onPrimaryTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isFollowAction
              ? const LinearGradient(colors: [Color(0xFFFF006E), Color(0xFFFF4499)])
              : null,
          color: isFollowAction
              ? null
              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: isFollowAction ? null : Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isOwnProfile ? Icons.edit_outlined : (widget.isFollowing ? Icons.check : Icons.person_add_alt_1),
              color: isFollowAction ? Colors.white : (isDark ? Colors.white : Colors.black87),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isOwnProfile ? 'Edit Profile' : (widget.isFollowing ? 'Following' : 'Follow'),
              style: TextStyle(
                color: isFollowAction ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: widget.onShareTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Center(
          child: Icon(
            Icons.ios_share_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
      ),
    );
  }
}
