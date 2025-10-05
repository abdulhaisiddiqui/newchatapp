import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactMessageWidget extends StatelessWidget {
  final String name;
  final String phone;
  final String? avatar;
  final bool isCurrentUser;

  const ContactMessageWidget({
    Key? key,
    required this.name,
    required this.phone,
    this.avatar,
    required this.isCurrentUser,
  }) : super(key: key);

  Future<void> _callContact() async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _sendMessage() async {
    final url = 'sms:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.blue[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: isCurrentUser ? Colors.white : Colors.blue[100],
            backgroundImage: avatar != null ? NetworkImage(avatar!) : null,
            child: avatar == null
                ? Icon(
                    Icons.person,
                    color: isCurrentUser ? Colors.blue : Colors.white,
                    size: 24,
                  )
                : null,
          ),

          const SizedBox(width: 12),

          // Contact Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isCurrentUser ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 14,
                    color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Action Buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.phone,
                  color: isCurrentUser ? Colors.white : Colors.green,
                  size: 20,
                ),
                onPressed: _callContact,
                tooltip: 'Call $name',
              ),

              const SizedBox(height: 4),

              // Message Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.message,
                  color: isCurrentUser ? Colors.white : Colors.blue,
                  size: 20,
                ),
                onPressed: _sendMessage,
                tooltip: 'Message $name',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
