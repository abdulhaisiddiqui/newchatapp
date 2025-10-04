import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';

class StoryViewerPage extends StatefulWidget {
  final Map<String, dynamic> userData; // ek user ke liye
  const StoryViewerPage({super.key, required this.userData});

  @override
  _StoryViewerPageState createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  final StoryController _storyController = StoryController();
  late List<StoryItem> _storyItems;

  @override
  void initState() {
    super.initState();
    _buildStoryItems();
  }

  void _buildStoryItems() {
    final List<dynamic> userStories = widget.userData["stories"] ?? [];
    _storyItems = userStories.map((story) {
      final storyData = Map<String, dynamic>.from(story);

      if (storyData["type"] == "image") {
        return StoryItem.pageImage(
          url: storyData["url"] ?? "",
          controller: _storyController,
          caption: widget.userData["username"] ?? "Unknown",
          duration: const Duration(seconds: 5),
        );
      } else if (storyData["type"] == "video") {
        return StoryItem.pageVideo(
          storyData["url"] ?? "",
          controller: _storyController,
          caption: widget.userData["username"] ?? "Unknown",
          duration: const Duration(seconds: 10),
        );
      } else {
        // Text story
        return StoryItem.text(
          title: storyData["text"] ?? "",
          backgroundColor: Colors.blue,
          textStyle: const TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }).toList();
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StoryView(
        storyItems: _storyItems,
        controller: _storyController,
        onComplete: () => Navigator.of(context).pop(),
        onVerticalSwipeComplete: (direction) {
          if (direction == Direction.down) {
            Navigator.of(context).pop();
          }
        },
        progressPosition: ProgressPosition.top,
        repeat: false,
        inline: false,
      ),
    );
  }
}
