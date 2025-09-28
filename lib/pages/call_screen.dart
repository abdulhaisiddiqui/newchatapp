import 'package:flutter/material.dart';
import '../components/bottom_navigation_bar.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: SafeArea(
        child: Column(
          children: [
            // Status Bar - Simplified with just time
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.06,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '9:41',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: MediaQuery.of(context).size.width * 0.04,
                    ),
                  ),
                ],
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.06,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.search,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.05,
                    ),
                  ),
                  Text(
                    'Calls',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.05,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.of(context).size.width * 0.06,
                        24,
                        MediaQuery.of(context).size.width * 0.06,
                        0,
                      ),
                      child: Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.of(context).size.width * 0.06,
                          16,
                          MediaQuery.of(context).size.width * 0.06,
                          0,
                        ),
                        children: [
                          _buildCallItem(
                            name: 'Team Align',
                            time: 'Today, 09:30 AM',
                            callType: CallType.incoming,
                            avatarUrl:
                                'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=80&h=80&fit=crop&crop=face',
                            isGroup: true,
                          ),
                          _buildCallItem(
                            name: 'Jhon Abraham',
                            time: 'Today, 07:30 AM',
                            callType: CallType.incoming,
                            avatarUrl:
                                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop&crop=face',
                          ),
                          _buildCallItem(
                            name: 'Sabila Sayma',
                            time: 'Yesterday, 07:35 PM',
                            callType: CallType.missed,
                            avatarUrl:
                                'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=80&h=80&fit=crop&crop=face',
                          ),
                          _buildCallItem(
                            name: 'Alex Linderson',
                            time: 'Monday, 09:30 AM',
                            callType: CallType.incoming,
                            avatarUrl:
                                'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80&h=80&fit=crop&crop=face',
                          ),
                          _buildCallItem(
                            name: 'Jhon Abraham',
                            time: '03/07/22, 07:30 AM',
                            callType: CallType.missed,
                            avatarUrl:
                                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop&crop=face',
                          ),
                          _buildCallItem(
                            name: 'John Borino',
                            time: 'Monday, 09:30 AM',
                            callType: CallType.outgoing,
                            avatarUrl:
                                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80&h=80&fit=crop&crop=face',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Global Bottom Navigation
            GlobalBottomNavigationBar(
              currentIndex: 1, // Calls tab is active
              onTap: (index) {
                // Handle navigation to other screens
                // This would typically use Navigator or a state management solution
              },
              isCallScreen: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallItem({
    required String name,
    required String time,
    required CallType callType,
    required String avatarUrl,
    bool isGroup = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Avatar with group indicator
          Stack(
            children: [
              CircleAvatar(
                radius: MediaQuery.of(context).size.width * 0.06,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              if (isGroup)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.06,
                    height: MediaQuery.of(context).size.width * 0.06,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.group,
                        size: MediaQuery.of(context).size.width * 0.03,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: MediaQuery.of(context).size.width * 0.03),

          // Name and call info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.04,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                Row(
                  children: [
                    Icon(
                      _getCallIcon(callType),
                      size: MediaQuery.of(context).size.width * 0.035,
                      color: _getCallColor(callType),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.032,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.phone, color: Color(0xFF6B7280)),
                iconSize: 20,
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.videocam, color: Color(0xFF6B7280)),
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }



  IconData _getCallIcon(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_received;
    }
  }

  Color _getCallColor(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return const Color(0xFF10B981);
      case CallType.outgoing:
        return const Color(0xFF3B82F6);
      case CallType.missed:
        return const Color(0xFFEF4444);
    }
  }
}

enum CallType { incoming, outgoing, missed }
