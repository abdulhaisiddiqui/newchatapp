import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl; // Firebase Storage URL or local path
  final bool isCurrentUser;

  const VoiceMessageWidget({
    Key? key,
    required this.audioUrl,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  _VoiceMessageWidgetState createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late final PlayerController _playerController;
  bool _isInitialized = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      setState(() => _isLoading = true);
      await _playerController.preparePlayer(path: widget.audioUrl);
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing audio: $e');
      setState(() => _isLoading = false);
    }
  }

  void _togglePlayPause() async {
    if (!_isInitialized) return;

    try {
      if (_playerController.playerState.isPlaying) {
        await _playerController.pausePlayer();
      } else {
        await _playerController.startPlayer();
      }
      setState(() {}); // Update UI
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isCurrentUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 120,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 250),
      decoration: BoxDecoration(
        color: widget.isCurrentUser ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _playerController.playerState.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: widget.isCurrentUser ? Colors.white : Colors.black,
              size: 24,
            ),
            onPressed: _togglePlayPause,
          ),

          const SizedBox(width: 8),

          // Audio Waveform
          Expanded(
            child: AudioFileWaveforms(
              size: const Size(double.infinity, 32),
              playerController: _playerController,
              playerWaveStyle: const PlayerWaveStyle(
                fixedWaveColor: Colors.grey,
                liveWaveColor: Colors.blue,
                showSeekLine: true,
              ),
              waveformType: WaveformType.fitWidth,
            ),
          ),

          const SizedBox(width: 8),

          // Duration (simplified - you can enhance this)
          Text(
            '0:00', // You can get duration from playerController if needed
            style: TextStyle(
              color: widget.isCurrentUser ? Colors.white : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
