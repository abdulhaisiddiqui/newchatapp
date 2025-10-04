import 'dart:async';
import 'package:uuid/uuid.dart';
import 'call_models.dart';
import 'call_service.dart';

/// Interface for CallManager
abstract class CallManagerInterface {
  bool get isInitialized;
  Future<void> initialize();
  bool get isInCall;
  CallInfo? get currentCall;
  void registerCallStateListener(CallStateListener listener);
  void unregisterCallStateListener(CallStateListener listener);
  Future<bool> startAudioCall(String userId, String userName);
  Future<bool> startVideoCall(String userId, String userName);
  Future<bool> answerCall();
  Future<bool> endCall();
  Future<bool> declineCall();
  Future<List<CallHistoryEntry>> getCallHistory(String userId);
  void handleIncomingCall(
    String callId,
    String userId,
    String userName,
    bool isVideo,
  );
  void dispose(); // ✅ Added cleanup
}

/// CallManager is a singleton class that manages call state and operations
class CallManager implements CallManagerInterface {
  // Singleton instance
  static CallManagerInterface? _instance;

  // Call service instance
  final CallService _callService = CallService();

  // Current call information
  CallInfo? _currentCall;

  // List of call state listeners
  final List<CallStateListener> _listeners = [];

  // Call history cache
  final Map<String, List<CallHistoryEntry>> _callHistoryCache = {};

  // Private constructor
  CallManager._();

  // Public constructor for testing
  CallManager() : this._();

  // Static getter for instance
  static CallManagerInterface get instance {
    _instance ??= CallManager._();
    return _instance!;
  }

  // For testing purposes only
  static void setInstanceForTesting(CallManagerInterface manager) {
    _instance = manager;
  }

  // Initialization flag
  bool _isInitialized = false;

  // Check if initialized
  bool get isInitialized => _isInitialized;

  // Initialize the call manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    // ✅ START LISTENING FOR INCOMING CALLS
    _callService.startListeningForCalls((callId, userId, userName, isVideo) {
      handleIncomingCall(callId, userId, userName, isVideo);
    });

    _isInitialized = true;
  }

  // Dispose method for cleanup
  void dispose() {
    _callService.stopListeningForCalls();
    _listeners.clear();
  }

  // Check if there's an active call
  bool get isInCall =>
      _currentCall != null &&
      (_currentCall!.state == CallState.connecting ||
          _currentCall!.state == CallState.ringing ||
          _currentCall!.state == CallState.connected);

  // Get current call info
  CallInfo? get currentCall => _currentCall;

  // Register a call state listener
  void registerCallStateListener(CallStateListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      listener.init();
    }
  }

  // Unregister a call state listener
  void unregisterCallStateListener(CallStateListener listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners of a call state change
  void _notifyCallStateChanged(CallInfo callInfo, CallState state) {
    for (var listener in _listeners) {
      listener.onCallStateChanged(callInfo, state);
    }
  }

  // Notify all listeners that a call has ended
  void _notifyCallEnded(CallInfo callInfo, CallEndReason reason) {
    for (var listener in _listeners) {
      listener.onCallEnded(callInfo, reason);
    }
  }

  // Start an audio call
  Future<bool> startAudioCall(String userId, String userName) async {
    if (isInCall) {
      return false;
    }

    final callId = const Uuid().v4();
    _currentCall = CallInfo(
      callId: callId,
      userId: userId,
      userName: userName,
      startTime: DateTime.now(),
      isVideo: false,
      state: CallState.connecting,
    );

    _notifyCallStateChanged(_currentCall!, CallState.connecting);

    final success = await _callService.initiateCall(
      callId,
      userId,
      false, // isVideo
    );

    if (success) {
      _currentCall!.state = CallState.ringing;
      _notifyCallStateChanged(_currentCall!, CallState.ringing);
      return true;
    } else {
      _endCall(CallEndReason.error);
      return false;
    }
  }

  // Start a video call
  Future<bool> startVideoCall(String userId, String userName) async {
    if (isInCall) {
      return false;
    }

    final callId = const Uuid().v4();
    _currentCall = CallInfo(
      callId: callId,
      userId: userId,
      userName: userName,
      startTime: DateTime.now(),
      isVideo: true,
      state: CallState.connecting,
    );

    _notifyCallStateChanged(_currentCall!, CallState.connecting);

    final success = await _callService.initiateCall(
      callId,
      userId,
      true, // isVideo
    );

    if (success) {
      _currentCall!.state = CallState.ringing;
      _notifyCallStateChanged(_currentCall!, CallState.ringing);
      return true;
    } else {
      _endCall(CallEndReason.error);
      return false;
    }
  }

  // Answer an incoming call
  Future<bool> answerCall() async {
    if (_currentCall == null || _currentCall!.state != CallState.ringing) {
      return false;
    }

    final success = await _callService.answerCall(_currentCall!.callId);

    if (success) {
      _currentCall!.state = CallState.connected;
      _notifyCallStateChanged(_currentCall!, CallState.connected);
      return true;
    } else {
      _endCall(CallEndReason.error);
      return false;
    }
  }

  // End the current call
  Future<bool> endCall() async {
    return _endCall(CallEndReason.completed);
  }

  // Decline an incoming call
  Future<bool> declineCall() async {
    return _endCall(CallEndReason.declined);
  }

  // Internal method to end a call with a specific reason
  Future<bool> _endCall(CallEndReason reason) async {
    if (_currentCall == null) {
      return false;
    }

    final callInfo = _currentCall!;
    final success = await _callService.endCall(callInfo.callId);

    callInfo.state = CallState.ended;
    callInfo.endReason = reason;
    callInfo.duration = DateTime.now().difference(callInfo.startTime);

    _notifyCallEnded(callInfo, reason);
    _currentCall = null;

    // Add to call history
    _addToCallHistory(callInfo, reason);

    return success;
  }

  // Add a call to the history
  void _addToCallHistory(CallInfo callInfo, CallEndReason reason) {
    final userId = callInfo.userId;

    CallDirection direction;
    if (reason == CallEndReason.missed) {
      direction = CallDirection.missed;
    } else {
      direction = CallDirection.outgoing; // Assuming outgoing for now
    }

    final historyEntry = CallHistoryEntry(
      callId: callInfo.callId,
      userId: callInfo.userId,
      userName: callInfo.userName,
      timestamp: callInfo.startTime,
      duration: callInfo.duration,
      isVideo: callInfo.isVideo,
      direction: direction,
    );

    if (!_callHistoryCache.containsKey(userId)) {
      _callHistoryCache[userId] = [];
    }

    _callHistoryCache[userId]!.insert(0, historyEntry);

    // Persist call history
    _callService.saveCallHistory(userId, historyEntry);
  }

  // Get call history for a user
  Future<List<CallHistoryEntry>> getCallHistory(String userId) async {
    if (_callHistoryCache.containsKey(userId)) {
      return _callHistoryCache[userId]!;
    }

    final history = await _callService.getCallHistory(userId);
    _callHistoryCache[userId] = history;
    return history;
  }

  // Handle an incoming call
  void handleIncomingCall(
    String callId,
    String userId,
    String userName,
    bool isVideo,
  ) {
    if (isInCall) {
      // Auto decline if already in a call
      _callService.declineCall(callId);
      return;
    }

    _currentCall = CallInfo(
      callId: callId,
      userId: userId,
      userName: userName,
      startTime: DateTime.now(),
      isVideo: isVideo,
      state: CallState.ringing,
    );

    _notifyCallStateChanged(_currentCall!, CallState.ringing);
  }
}
