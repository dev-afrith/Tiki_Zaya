import 'dart:async';

import 'package:flutter/material.dart';

class TZPointsWidget extends StatefulWidget {
  final int points;
  final VoidCallback? onTap;
  final bool compact;
  final bool fullWidth;

  const TZPointsWidget({
    super.key,
    required this.points,
    this.onTap,
    this.compact = true,
    this.fullWidth = false,
  });

  @override
  State<TZPointsWidget> createState() => _TZPointsWidgetState();
}

class _TZPointsWidgetState extends State<TZPointsWidget> {
  int _previousPoints = 0;
  int _delta = 0;
  bool _showDelta = false;
  Timer? _deltaTimer;

  @override
  void initState() {
    super.initState();
    _previousPoints = widget.points;
  }

  @override
  void didUpdateWidget(covariant TZPointsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points > oldWidget.points) {
      _deltaTimer?.cancel();
      setState(() {
        _delta = widget.points - oldWidget.points;
        _showDelta = true;
      });
      _deltaTimer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _showDelta = false;
        });
      });
    }
    _previousPoints = oldWidget.points;
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: widget.compact ? 12.5 : 28,
      letterSpacing: 0.1,
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: widget.fullWidth ? double.infinity : null,
            constraints: widget.fullWidth ? const BoxConstraints(minHeight: 84, maxHeight: 84) : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 16,
              vertical: widget.compact ? 7 : 12,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              ),
              borderRadius: BorderRadius.circular(widget.compact ? 999 : 16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x660072FF),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  width: widget.compact ? 18 : 30,
                  height: widget.compact ? 18 : 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'TZ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: widget.compact ? 7 : 10,
                    ),
                  ),
                ),
                SizedBox(width: widget.compact ? 6 : 10),
                if (!widget.compact)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'TZ Points',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _previousPoints.toDouble(), end: widget.points.toDouble()),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      value.round().toString(),
                      style: textStyle,
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            right: widget.compact ? 0 : 8,
            top: widget.compact ? -18 : -20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _showDelta
                  ? Container(
                      key: ValueKey<int>(_delta),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF00C6FF)),
                      ),
                      child: Text(
                        '+$_delta',
                        style: const TextStyle(
                          color: Color(0xFF6AD9FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class StreakWidget extends StatefulWidget {
  final int days;
  final bool compact;
  final bool fullWidth;

  const StreakWidget({
    super.key,
    required this.days,
    this.compact = true,
    this.fullWidth = false,
  });

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> {
  double _scale = 1;
  Timer? _pulseTimer;

  @override
  void didUpdateWidget(covariant StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.days != oldWidget.days) {
      _pulseTimer?.cancel();
      setState(() => _scale = 1.06);
      _pulseTimer = Timer(const Duration(milliseconds: 240), () {
        if (!mounted) return;
        setState(() => _scale = 1);
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Container(
        width: widget.fullWidth ? double.infinity : null,
        constraints: widget.fullWidth ? const BoxConstraints(minHeight: 84, maxHeight: 84) : null,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 14,
          vertical: widget.compact ? 7 : 12,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF3D3D), Color(0xFFFF8A00)],
          ),
          borderRadius: BorderRadius.circular(widget.compact ? 999 : 16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x52FF7A00),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: widget.compact ? 15 : 22,
            ),
            SizedBox(width: widget.compact ? 5 : 8),
            Expanded(
              child: Text(
                '${widget.days} Day Streak',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: widget.compact ? 12.5 : 16,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskProgressWidget extends StatelessWidget {
  final String title;
  final int currentValue;
  final int targetValue;
  final String unit;
  final int rewardPoints;
  final bool completed;
  final Widget? action;

  const TaskProgressWidget({
    super.key,
    required this.title,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    required this.rewardPoints,
    required this.completed,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final safeTarget = targetValue <= 0 ? 1 : targetValue;
    final progress = (currentValue / safeTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: completed ? const Color(0xFF2F7AE5) : const Color(0xFF293245)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (action != null)
                action!
              else
                Text(
                  '+$rewardPoints TZ',
                  style: TextStyle(
                    color: completed ? const Color(0xFF7ED7FF) : const Color(0xFF9BA8BC),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: const Color(0xFF1A2230),
              valueColor: AlwaysStoppedAnimation<Color>(
                completed ? const Color(0xFF2F7AE5) : const Color(0xFF6AD9FF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentValue/$targetValue $unit',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class RewardProgressBar extends StatelessWidget {
  final int currentPoints;
  final int targetPoints;

  const RewardProgressBar({
    super.key,
    required this.currentPoints,
    this.targetPoints = 2500,
  });

  @override
  Widget build(BuildContext context) {
    final safeTarget = targetPoints <= 0 ? 2500 : targetPoints;
    final remaining = (safeTarget - currentPoints).clamp(0, safeTarget).toInt();
    final progress = (currentPoints / safeTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF293245)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Surprise Reward',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$currentPoints / $safeTarget',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: const Color(0xFF1A2230),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6AD9FF)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$remaining TZ more to unlock',
            style: const TextStyle(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class BadgeWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;

  const BadgeWidget({
    super.key,
    required this.icon,
    required this.label,
    this.unlocked = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF171C26) : const Color(0xFF0F1218),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? const Color(0xFF2E3C52) : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: unlocked ? const Color(0xFF8EC4FF) : Colors.white30,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
