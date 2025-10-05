import 'package:flutter/material.dart';
import '../services/user/user_status_service.dart';

class UserStatusIndicator extends StatelessWidget {
  final String userId;
  final bool showText;
  final double size;

  const UserStatusIndicator({
    Key? key,
    required this.userId,
    this.showText = true,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserStatus>(
      stream: UserStatusService().getUserStatus(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildStatusIndicator(color: Colors.grey, text: 'Loading...');
        }

        final status = snapshot.data!;
        return _buildStatusIndicator(
          color: status.getStatusColor(),
          text: showText ? status.getStatusText() : null,
        );
      },
    );
  }

  Widget _buildStatusIndicator({required Color color, String? text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        if (text != null && showText) ...[
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class TypingIndicator extends StatelessWidget {
  final String chatRoomId;
  final String currentUserId;

  const TypingIndicator({
    Key? key,
    required this.chatRoomId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: UserStatusService().getTypingUsers(chatRoomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final typingUsers = snapshot.data!
            .where((userId) => userId != currentUserId)
            .toList();

        if (typingUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, size: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  typingUsers.length == 1
                      ? 'Someone is typing...'
                      : '${typingUsers.length} people are typing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedTypingIndicator extends StatefulWidget {
  const AnimatedTypingIndicator({Key? key}) : super(key: key);

  @override
  State<AnimatedTypingIndicator> createState() =>
      _AnimatedTypingIndicatorState();
}

class _AnimatedTypingIndicatorState extends State<AnimatedTypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final delay = index * 0.2;
            final opacity = (_animation.value - delay).clamp(0.0, 1.0);
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
