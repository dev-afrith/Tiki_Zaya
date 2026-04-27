import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const ProfileTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: selectedIndex == 0 ? 2 : MediaQuery.of(context).size.width / 2 - 18,
              top: 2,
              bottom: 2,
              width: MediaQuery.of(context).size.width / 2 - 18,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTabChanged(0),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        'Posts',
                        style: TextStyle(
                          color: selectedIndex == 0
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white54 : Colors.black54),
                          fontWeight: selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTabChanged(1),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        'Reposts',
                        style: TextStyle(
                          color: selectedIndex == 1
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white54 : Colors.black54),
                          fontWeight: selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
