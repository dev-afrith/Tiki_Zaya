import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/discover_screen.dart';
import 'package:mobile/screens/upload_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/utils/update_checker.dart';
import 'package:mobile/services/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:mobile/widgets/badge_icon.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const DiscoverScreen(),
    const UploadScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchCounts();
    });
    // Automatic check for updates on startup
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) UpdateChecker.checkAndShowDialog(context, silent: true);
    });
  }

  void _onTabTap(int index) {
    setState(() { _currentIndex = index; });
    // Refresh unread count when navigating away from chat
    if (index != 3) {
      Provider.of<NotificationProvider>(context, listen: false).fetchCounts();
    } else {
      // Clear badge when entering chat
      Provider.of<NotificationProvider>(context, listen: false).setUnreadMessages(0);
    }
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex != 0,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() { _currentIndex = 0; });
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF161616),
              title: const Text('Exit App?', style: TextStyle(color: Colors.white)),
              content: const Text('Are you sure you want to exit?', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
              ],
            ),
          );
          if (shouldExit == true) {
             SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xCC0A0A0A),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home_filled),
                      _buildNavItem(1, Icons.search_rounded, Icons.search),
                      _buildCenterButton(),
                      Consumer<NotificationProvider>(
                        builder: (context, provider, child) {
                          return _buildNavItemWithBadge(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, provider.unreadMessages);
                        },
                      ),
                      _buildNavItem(4, Icons.person_outline, Icons.person),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),);
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 50,
        height: 40,
        child: Center(
          child: Icon(
            isActive ? filledIcon : outlineIcon,
            color: isActive ? const Color(0xFFFF3B8E) : Colors.white38,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(int index, IconData outlineIcon, IconData filledIcon, int badgeCount) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 50,
        height: 40,
        child: Center(
          child: BadgeIcon(
            icon: isActive ? filledIcon : outlineIcon,
            color: isActive ? const Color(0xFFFF3B8E) : Colors.white38,
            iconSize: 28,
            count: badgeCount,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () => _onTabTap(2),
      child: Container(
        width: 46,
        height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3B8E), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
             BoxShadow(
              color: const Color(0xFFFF3B8E).withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}
