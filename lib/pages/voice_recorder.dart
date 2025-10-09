import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(String) onStop;
  final Function()? onCancel;

  const VoiceRecorder({
    Key? key,
    required this.onStop,
    this.onCancel,
  }) : super(key: key);

  @override
  _VoiceRecorderState createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      debugPrint('Checking microphone permission');
      PermissionStatus micStatus = await Permission.microphone.status;
      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          debugPrint('Microphone permission denied');
          _showPermissionDeniedDialog();
          widget.onStop('');
          widget.onCancel?.call();
          return;
        }
      }
      debugPrint('Microphone permission granted');

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _audioPath = '${tempDir.path}/voice_message_$timestamp.m4a';
      debugPrint('Recording path: $_audioPath');

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _audioPath!,
      );
      debugPrint('Recording started');

      setState(() {
        _isRecording = true;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _showErrorSnackBar('Failed to start recording: $e');
      widget.onStop('');
      widget.onCancel?.call();
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();
      _pulseController.stop();
      debugPrint('Recording stopped, path: $path');

      if (path != null && File(path).existsSync()) {
        final fileSize = await File(path).length();
        debugPrint('Audio file exists, path: $path, size: $fileSize bytes');
        widget.onStop(path);
      } else {
        debugPrint('No audio file recorded at path: $path');
        _showErrorSnackBar('No audio file recorded');
        widget.onStop('');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _showErrorSnackBar('Failed to stop recording: $e');
      widget.onStop('');
    } finally {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
    }
  }

  void _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      _timer?.cancel();
      _pulseController.stop();
      debugPrint('Recording cancelled');
      widget.onStop('');
      widget.onCancel?.call();
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
      _showErrorSnackBar('Failed to cancel recording: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text('Please grant microphone permission to record voice messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: const Icon(
                  Icons.mic,
                  color: Colors.red,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Recording...' : 'Stopped',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _cancelRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.close, color: Colors.black),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _stopRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to stop or cancel recording',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}