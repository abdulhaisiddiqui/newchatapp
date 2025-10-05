import 'dart:async';
import 'package:chatapp/services/story/story_service.dart';
import 'package:flutter/material.dart'; // 👈 apna StoryService import karo

class StoryViewerPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StoryViewerPage({super.key, required this.userData});

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  final StoryService _storyService = StoryService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _startAnimating();
    _markCurrentAsViewed(); // 👈 start me hi mark karo
  }

  void _startAnimating() {
    _animController.stop();
    _animController.reset();
    _animController.forward();
  }

  void _markCurrentAsViewed() {
    final stories = widget.userData["stories"] ?? [];
    if (stories.isEmpty) return;

    final currentStory = stories[_currentIndex];
    final storyId = currentStory["storyId"];
    final storyDocId = widget.userData["userId"];

    if (storyId != null && storyDocId != null) {
      _storyService.markStoryAsViewed(storyDocId, storyId);
    }
  }

  void _nextStory() {
    final stories = widget.userData["stories"] ?? [];
    if (_currentIndex < stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _markCurrentAsViewed(); // 👈 next pe mark karo
      _startAnimating();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _markCurrentAsViewed(); // 👈 previous pe bhi mark karo
      _startAnimating();
    } else {
      _startAnimating();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.userData["stories"] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final username = widget.userData["username"] ?? "Unknown";
            final userId = widget.userData["userId"];
            if (userId != null) {
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {"userId": userId, "username": username},
              );
            }
          },
          child: Text(
            widget.userData["username"] ?? "Unknown",
            style: const TextStyle(color: Colors.white),
          ),
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // 🔹 Story content
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                final type = story["type"];
                if (type == "image" && story["url"] != "") {
                  return Center(
                    child: Image.network(
                      story["url"],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.error, color: Colors.white),
                    ),
                  );
                } else {
                  return Center(
                    child: Text(
                      story["text"] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
              },
            ),

            // 🔹 Timeline Progress Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Row(
                  children: List.generate(stories.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            double value;
                            if (index < _currentIndex) {
                              value = 1;
                            } else if (index == _currentIndex) {
                              value = _animController.value;
                            } else {
                              value = 0;
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor:
                                Colors.white.withOpacity(0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
