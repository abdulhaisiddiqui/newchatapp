import 'package:flutter/material.dart';
import 'dart:async';
import '../components/call/incoming_call_dialog.dart';
import '../components/error_dialog.dart';
import '../services/call/call_manager.dart';
import '../services/call/call_models.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> implements CallStateListener {
  final CallManagerInterface _callManager = CallManager.instance;
  List<CallHistoryEntry> _callHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCallService();
  }

  Future<void> _initializeCallService() async {
    try {
      _callManager.registerCallStateListener(this);
      await _loadCallHistory();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize call service: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCallHistory() async {
    try {
      final history = await _callManager.getCallHistory('');
      setState(() {
        _callHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load call history: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _callManager.unregisterCallStateListener(this);
    super.dispose();
  }

  @override
  void init() {
    // Initialize call state listener
  }

  @override
  void onCallStateChanged(CallInfo callInfo, CallState state) {
    setState(() {
      // Update UI based on call state
      if (state == CallState.ringing && callInfo.state == CallState.ringing) {
        _showIncomingCallDialog(callInfo);
      }
    });
  }

  @override
  void onCallEnded(CallInfo callInfo, CallEndReason reason) {
    // Refresh call history after call ends
    _loadCallHistory();
  }

  void _startAudioCall(String userId, String userName) async {
    try {
      final success = await _callManager.startAudioCall(userId, userName);
      if (!success) {
        _showErrorDialog('Failed to start audio call');
      }
    } catch (e) {
      _showErrorDialog('Error starting call: $e');
    }
  }

  void _startVideoCall(String userId, String userName) async {
    try {
      final success = await _callManager.startVideoCall(userId, userName);
      if (!success) {
        _showErrorDialog('Failed to start video call');
      }
    } catch (e) {
      _showErrorDialog('Error starting call: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(title: 'Call Error', message: message),
    );
  }

  void _showIncomingCallDialog(CallInfo callInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(
        callInfo: callInfo,
        onAccept: () {
          Navigator.of(context).pop();
          _callManager.answerCall();
        },
        onDecline: () {
          Navigator.of(context).pop();
          _callManager.declineCall();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.06,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.search,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.05,
                    ),
                  ),
                  Text(
                    'Calls',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.05,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              MediaQuery.of(context).size.width * 0.06,
                              24,
                              MediaQuery.of(context).size.width * 0.06,
                              0,
                            ),
                            child: Text(
                              'Recent',
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.045,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),

                          Expanded(
                            child: _callHistory.isEmpty
                                ? Center(
                                    child: Text(
                                      'No recent calls',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize:
                                            MediaQuery.of(context).size.width *
                                            0.04,
                                      ),
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadCallHistory,
                                    child: ListView.builder(
                                      padding: EdgeInsets.fromLTRB(
                                        MediaQuery.of(context).size.width *
                                            0.06,
                                        16,
                                        MediaQuery.of(context).size.width *
                                            0.06,
                                        0,
                                      ),
                                      itemCount: _callHistory.length,
                                      itemBuilder: (context, index) {
                                        final call = _callHistory[index];
                                        return _buildCallHistoryItem(call);
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistoryItem(CallHistoryEntry call) {
    final CallScreenType callScreenType;
    switch (call.direction) {
      case CallDirection.incoming:
        callScreenType = CallScreenType.incoming;
        break;
      case CallDirection.outgoing:
        callScreenType = CallScreenType.outgoing;
        break;
      case CallDirection.missed:
        callScreenType = CallScreenType.missed;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Avatar with group indicator
          CircleAvatar(
            radius: MediaQuery.of(context).size.width * 0.06,
            backgroundImage: call.userAvatar != null
                ? NetworkImage(call.userAvatar!)
                : null,
            child: call.userAvatar == null
                ? Icon(
                    Icons.person,
                    size: MediaQuery.of(context).size.width * 0.06,
                    color: Colors.white,
                  )
                : null,
          ),

          SizedBox(width: MediaQuery.of(context).size.width * 0.03),

          // Name and call info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.userName,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.04,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                Row(
                  children: [
                    Icon(
                      _getCallIcon(callScreenType),
                      size: MediaQuery.of(context).size.width * 0.035,
                      color: _getCallColor(callScreenType),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                    Expanded(
                      child: Text(
                        _formatCallTime(call.timestamp, call.duration),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.032,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              IconButton(
                onPressed: () => _startAudioCall(call.userId, call.userName),
                icon: const Icon(Icons.call, color: Color(0xFF6B7280)),
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => _startVideoCall(call.userId, call.userName),
                icon: const Icon(Icons.videocam, color: Color(0xFF6B7280)),
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCallTime(DateTime timestamp, Duration? duration) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    String timeString;
    if (difference.inDays == 0) {
      // Today
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      timeString = 'Today, $hour:$minute';
    } else if (difference.inDays == 1) {
      // Yesterday
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      timeString = 'Yesterday, $hour:$minute';
    } else if (difference.inDays < 7) {
      // This week
      final weekday = _getWeekdayName(timestamp.weekday);
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      timeString = '$weekday, $hour:$minute';
    } else {
      // Older
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      final year = timestamp.year.toString().substring(2);
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      timeString = '$day/$month/$year, $hour:$minute';
    }

    if (duration != null) {
      final minutes = duration.inMinutes;
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      timeString += ' ($minutes:$seconds)';
    }

    return timeString;
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  IconData _getCallIcon(CallScreenType callType) {
    switch (callType) {
      case CallScreenType.incoming:
        return Icons.call_received;
      case CallScreenType.outgoing:
        return Icons.call_made;
      case CallScreenType.missed:
        return Icons.call_missed;
    }
  }

  Color _getCallColor(CallScreenType callType) {
    switch (callType) {
      case CallScreenType.incoming:
        return const Color(0xFF10B981);
      case CallScreenType.outgoing:
        return const Color(0xFF3B82F6);
      case CallScreenType.missed:
        return const Color(0xFFEF4444);
    }
  }

  // Invalid methods removed to align with CallStateListener interface and fix syntax errors
}

enum CallScreenType { incoming, outgoing, missed }
