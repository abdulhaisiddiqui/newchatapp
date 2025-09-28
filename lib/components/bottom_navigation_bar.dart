import 'package:flutter/material.dart';

class GlobalBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isCallScreen;

  const GlobalBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.isCallScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCallScreen ? Colors.white : const Color(0xFF1F2937),
        border: isCallScreen
            ? const Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.message,
            label: 'Message',
            index: 0,
            isActive: currentIndex == 0,
            isCallScreen: isCallScreen,
          ),
          _buildNavItem(
            icon: Icons.phone,
            label: 'Calls',
            index: 1,
            isActive: currentIndex == 1,
            isCallScreen: isCallScreen,
          ),
          _buildNavItem(
            icon: Icons.people,
            label: 'Contacts',
            index: 2,
            isActive: currentIndex == 2,
            isCallScreen: isCallScreen,
          ),
          _buildNavItem(
            icon: Icons.settings,
            label: 'Settings',
            index: 3,
            isActive: currentIndex == 3,
            isCallScreen: isCallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
    required bool isCallScreen,
  }) {
    final activeColor = isCallScreen ? const Color(0xFF10B981) : Colors.white;
    final inactiveColor = isCallScreen ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}