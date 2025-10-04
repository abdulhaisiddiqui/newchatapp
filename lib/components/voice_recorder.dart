import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VoiceRecorder extends StatefulWidget {
  final Function(String path) onStop; // callback after recording stops

  const VoiceRecorder({Key? key, required this.onStop}) : super(key: key);

  @override
  _VoiceRecorderState createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  late final RecorderController _recorderController;
  String? _recordingPath;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac";

      await _recorderController.record(path: _recordingPath!);
      setState(() => _isRecording = true);
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorderController.stop();
      setState(() => _isRecording = false);

      if (_recordingPath != null) {
        widget.onStop(_recordingPath!);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  @override
  void dispose() {
    _recorderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? Colors.red : Colors.grey[300],
          boxShadow: _isRecording
              ? [const BoxShadow(color: Colors.red, blurRadius: 10)]
              : null,
        ),
        child: _isRecording
            ? AudioWaveforms(
                size: const Size(40, 40),
                recorderController: _recorderController,
                waveStyle: const WaveStyle(
                  waveColor: Colors.white,
                  extendWaveform: true,
                  showMiddleLine: false,
                ),
              )
            : const Icon(Icons.mic, color: Colors.black, size: 24),
      ),
    );
  }
}
