import 'package:flutter/material.dart';

class StoryViewerPage extends StatelessWidget {
  final Map<String, dynamic> userData; // ek user ke liye
  const StoryViewerPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> userStories = userData["stories"] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(userData["username"] ?? "Unknown"),
      ),
      body: PageView.builder(
        itemCount: userStories.length,
        itemBuilder: (context, index) {
          final story = userStories[index];
          if (story["type"] == "image") {
            return Center(
              child: Image.network(story["url"], fit: BoxFit.contain),
            );
          } else {
            return Center(
              child: Text(
                story["text"] ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            );
          }
        },
      ),
    );
  }
}
