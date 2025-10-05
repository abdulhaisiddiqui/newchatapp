import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;

  const VideoMessageWidget({required this.videoUrl});

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
      });

    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 250, maxHeight: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Player
            _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : Container(
                    height: 200,
                    color: Colors.black,
                    child: Center(child: CircularProgressIndicator()),
                  ),

            // Play/Pause Overlay
            if (_isInitialized)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 60,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),

            // Progress Bar
            if (_isInitialized && _controller.value.isPlaying)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.teal,
                    bufferedColor: Colors.grey.shade400,
                    backgroundColor: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
