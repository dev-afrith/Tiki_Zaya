import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/gamification_widgets.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool _isLoading = true;
  bool _isClaiming = false;
  Map<String, dynamic> _summary = const {};
  List<dynamic> _leaderboard = const [];
  late final Future<void> Function() _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = () async {
      while (mounted) {
        await Future<void>.delayed(const Duration(seconds: 12));
        if (mounted && !_isClaiming) {
          await _load(silent: true);
        }
      }
    };
    _poller();
  }

  Future<void> _load({bool silent = false}) async {
    if (mounted && !silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final summary = await ApiService.getGamificationSummary();
      final leaderboard = await ApiService.getLeaderboard();

      if (!mounted) return;
      setState(() {
        _summary = summary['gamification'] as Map<String, dynamic>? ?? const {};
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimTask(String taskId) async {
    await _claim(() => ApiService.claimTaskReward(taskId));
  }

  Future<void> _claimReward(String rewardId) async {
    await _claim(() => ApiService.claimMilestoneReward(rewardId));
  }

  Future<void> _claim(Future<Map<String, dynamic>> Function() action) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    try {
      final result = await action();
      if (result['gamification'] is Map<String, dynamic>) {
        setState(() {
          _summary = result['gamification'] as Map<String, dynamic>;
        });
      } else {
        await _load(silent: true);
      }
      if (!mounted) return;
      final awarded = (result['awardedPoints'] is num) ? (result['awardedPoints'] as num).toInt() : 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(awarded > 0 ? '+$awarded TZ Points claimed' : (result['message'] ?? 'Reward updated').toString())),
      );
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badges = (_summary['badges'] as List?)?.map((item) => item.toString()).where((item) => item.isNotEmpty).toList() ?? const [];
    final tasks = (_summary['tasks'] as List?) ?? const [];
    final rewards = (_summary['rewards'] as List?) ?? const [];
    final rewardProgress = _summary['rewardProgress'] as Map<String, dynamic>? ?? const {};
    final currentPoints = (rewardProgress['currentPoints'] is num) ? (rewardProgress['currentPoints'] as num).toInt() : 0;
    final streakDays = (_summary['streakDays'] is num) ? (_summary['streakDays'] as num).toInt() : 0;
    final targetPoints = (rewardProgress['targetPoints'] is num) ? (rewardProgress['targetPoints'] as num).toInt() : 2500;

    return Scaffold(
      backgroundColor: const Color(0xFF090B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B10),
        elevation: 0,
        title: const Text(
          'Rewards',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6AD9FF)))
          : RefreshIndicator(
              color: const Color(0xFF6AD9FF),
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TZPointsWidget(
                          points: currentPoints,
                          compact: false,
                          fullWidth: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StreakWidget(
                          days: streakDays,
                          compact: false,
                          fullWidth: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RewardProgressBar(currentPoints: currentPoints, targetPoints: targetPoints),
                  const SizedBox(height: 16),
                  const Text(
                    'Task Progress',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (tasks.isEmpty)
                    const Text('No tasks available right now.', style: TextStyle(color: Colors.white54))
                  else
                    ...tasks.map((task) {
                      final taskMap = Map<String, dynamic>.from(task as Map);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TaskProgressWidget(
                          title: (taskMap['title'] ?? '').toString(),
                          currentValue: (taskMap['currentValue'] is num) ? (taskMap['currentValue'] as num).toInt() : 0,
                          targetValue: (taskMap['targetValue'] is num) ? (taskMap['targetValue'] as num).toInt() : 1,
                          unit: (taskMap['unit'] ?? '').toString(),
                          rewardPoints: (taskMap['rewardPoints'] is num) ? (taskMap['rewardPoints'] as num).toInt() : 0,
                          completed: taskMap['completed'] == true,
                          action: _taskAction(taskMap),
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                  const Text(
                    'Milestone Rewards',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (rewards.isEmpty)
                    const Text('No rewards configured yet.', style: TextStyle(color: Colors.white54))
                  else
                    ...rewards.map((reward) {
                      final item = Map<String, dynamic>.from(reward as Map);
                      return _RewardClaimTile(
                        title: (item['title'] ?? '').toString(),
                        description: (item['description'] ?? '').toString(),
                        rewardPoints: (item['rewardPoints'] is num) ? (item['rewardPoints'] as num).toInt() : 0,
                        status: (item['status'] ?? 'locked').toString(),
                        onClaim: item['status'] == 'claimable' ? () => _claimReward((item['id'] ?? '').toString()) : null,
                      );
                    }),
                  const SizedBox(height: 10),
                  const Text(
                    'Badges',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (badges.isEmpty)
                    const Text('No badges yet', style: TextStyle(color: Colors.white54))
                  else
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, index) {
                          final badge = badges[index];
                          return BadgeWidget(icon: Icons.verified, label: badge);
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: badges.length,
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    'Leaderboard',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_leaderboard.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('No leaderboard data yet', style: TextStyle(color: Colors.white54)),
                    )
                  else
                    ..._leaderboard.map((entry) {
                      final item = Map<String, dynamic>.from(entry as Map);
                      final rank = (item['rank'] is num) ? (item['rank'] as num).toInt() : 0;
                      final username = _displayName(item);
                      final points = (item['points'] is num) ? (item['points'] as num).toInt() : 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12151C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#$rank',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                username,
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.bolt_rounded, color: Color(0xFF6AD9FF), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              points.toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget? _taskAction(Map<String, dynamic> task) {
    final status = (task['status'] ?? '').toString();
    if (status == 'claimed') {
      return const Text('Claimed', style: TextStyle(color: Color(0xFF7ED7FF), fontSize: 12, fontWeight: FontWeight.w700));
    }
    if (status != 'claimable') return null;
    return TextButton(
      onPressed: _isClaiming ? null : () => _claimTask((task['id'] ?? '').toString()),
      child: const Text('Claim'),
    );
  }

  String _displayName(Map<String, dynamic> user) {
    final name = (user['name'] ?? '').toString().trim();
    final username = (user['username'] ?? '').toString().trim();
    if (name.isNotEmpty && name.toLowerCase() != 'user') return name;
    if (username.isNotEmpty && username.toLowerCase() != 'user') return '@$username';
    return 'TikiZaya Creator';
  }
}

class _RewardClaimTile extends StatelessWidget {
  final String title;
  final String description;
  final int rewardPoints;
  final String status;
  final VoidCallback? onClaim;

  const _RewardClaimTile({
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.status,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final claimable = status == 'claimable';
    final claimed = status == 'claimed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: claimable ? const Color(0xFF6AD9FF) : Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFF6AD9FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Text('+$rewardPoints TZ', style: const TextStyle(color: Color(0xFF7ED7FF), fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          if (claimed)
            const Text('Claimed', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700))
          else
            ElevatedButton(
              onPressed: onClaim,
              style: ElevatedButton.styleFrom(backgroundColor: claimable ? const Color(0xFF2F7AE5) : Colors.white12),
              child: Text(claimable ? 'Claim' : 'Locked', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
