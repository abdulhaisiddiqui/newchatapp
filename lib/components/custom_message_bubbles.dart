import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatview/chatview.dart';
import 'package:chatapp/model/custom_message.dart';

class CustomMessageBubbles {
  static Widget buildLocationBubble(CustomMessage msg, BuildContext context) {
    final lat = msg.extraData?['lat'];
    final lng = msg.extraData?['lng'];
    final address = msg.extraData?['address'] ?? 'Unknown location';

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.location_pin, color: Colors.red.shade600, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (lat != null && lng != null) {
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                  try {
                    await launchUrl(Uri.parse(url));
                  } catch (e) {
                    // Fallback to geo URL
                    final geoUrl = 'geo:$lat,$lng';
                    await launchUrl(Uri.parse(geoUrl));
                  }
                }
              },
              icon: const Icon(Icons.map, size: 16),
              label: const Text('View on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildContactBubble(CustomMessage msg, BuildContext context) {
    final name = msg.extraData?['name'] ?? 'Unknown';
    final phone = msg.extraData?['phone'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade200,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                  ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              onPressed: () async {
                final url = 'tel:$phone';
                try {
                  await launchUrl(Uri.parse(url));
                } catch (e) {
                  // Handle error silently
                }
              },
              icon: Icon(Icons.phone, color: Colors.blue.shade600, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  static Widget buildDocumentBubble(CustomMessage msg, BuildContext context) {
    final fileName = msg.extraData?['fileName'] ?? 'Document';
    final fileSize = msg.extraData?['fileSize'] ?? 0;
    final fileUrl = msg.extraData?['fileUrl'];

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize > 0)
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          if (fileUrl != null)
            IconButton(
              onPressed: () async {
                try {
                  await launchUrl(Uri.parse(fileUrl));
                } catch (e) {
                  // Handle error silently
                }
              },
              icon: Icon(Icons.download, color: Colors.grey.shade600, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
