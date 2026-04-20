import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/discover_screen.dart';
import 'package:mobile/screens/upload_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/chat_screen.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
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
                      _buildNavItem(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
                      _buildNavItem(4, Icons.person_outline, Icons.person),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() { _currentIndex = index; }),
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

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () => setState(() { _currentIndex = 2; }),
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
