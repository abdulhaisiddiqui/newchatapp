/// Enum representing the direction of a call
enum CallDirection { incoming, outgoing, missed }

/// Enum representing the current state of a call
enum CallState { idle, connecting, ringing, connected, ended }

/// Enum representing the reason a call ended
enum CallEndReason { completed, declined, missed, error, busy, canceled }

/// Class representing a call history entry
class CallHistoryEntry {
  final String callId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime timestamp;
  final Duration? duration;
  final bool isVideo;
  final CallDirection direction;

  CallHistoryEntry({
    required this.callId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.timestamp,
    this.duration,
    required this.isVideo,
    required this.direction,
  });
}

/// Class representing information about a current call
class CallInfo {
  final String callId;
  final String userId;
  final String userName;
  final DateTime startTime;
  final bool isVideo;
  CallState state;
  CallEndReason? endReason;
  Duration? duration;

  CallInfo({
    required this.callId,
    required this.userId,
    required this.userName,
    required this.startTime,
    required this.isVideo,
    this.state = CallState.idle,
    this.endReason,
    this.duration,
  });
}

/// Interface for call state listeners
abstract class CallStateListener {
  void onCallStateChanged(CallInfo callInfo, CallState state);
  void onCallEnded(CallInfo callInfo, CallEndReason reason);
  void init();
}
