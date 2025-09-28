import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/call/call_models.dart';

/// Widget for displaying the active call UI
class CallScreenWidget extends StatefulWidget {
  final CallInfo callInfo;
  final Function() onEndCall;

  const CallScreenWidget({
    Key? key,
    required this.callInfo,
    required this.onEndCall,
  }) : super(key: key);

  @override
  State<CallScreenWidget> createState() => _CallScreenWidgetState();
}

class _CallScreenWidgetState extends State<CallScreenWidget> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;
  bool _isCameraFront = true;
  Duration _callDuration = Duration.zero;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.callInfo.isVideo;
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // Implement actual mute functionality here
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // Implement actual speaker functionality here
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    // Implement actual video toggle functionality here
  }

  void _switchCamera() {
    setState(() {
      _isCameraFront = !_isCameraFront;
    });
    // Implement actual camera switch functionality here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video view or avatar
          Center(
            child: _isVideoEnabled
                ? Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Text(
                        'Video Stream',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.blue,
                        child: Text(
                          widget.callInfo.userName.isNotEmpty
                              ? widget.callInfo.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.callInfo.userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Call controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.red : Colors.white,
                  onPressed: _toggleMute,
                  label: 'Mute',
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: widget.onEndCall,
                  label: 'End',
                  isEndCall: true,
                ),
                _buildCallButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  color: _isSpeakerOn ? Colors.blue : Colors.white,
                  onPressed: _toggleSpeaker,
                  label: 'Speaker',
                ),
              ],
            ),
          ),
          
          // Video controls (only show if this is a video call)
          if (widget.callInfo.isVideo)
            Positioned(
              top: 50,
              right: 20,
              child: Column(
                children: [
                  _buildIconButton(
                    icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    onPressed: _toggleVideo,
                  ),
                  const SizedBox(height: 20),
                  _buildIconButton(
                    icon: Icons.flip_camera_ios,
                    onPressed: _switchCamera,
                  ),
                ],
              ),
            ),
            
          // Status bar for safe area
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEndCall ? Colors.red : Colors.grey[800],
          ),
          child: IconButton(
            icon: Icon(icon),
            color: color,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: Colors.white,
        onPressed: onPressed,
      ),
    );
  }
}