import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:mobile/services/call_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final int uid;
  final String callerName;
  final String callerPic;
  final bool isVideo;
  final bool isIncoming;
  final int? remoteUid;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.callerName,
    this.callerPic = '',
    required this.isVideo,
    this.isIncoming = false,
    this.remoteUid,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerPhone = true;
  Timer? _callTimer;
  Timer? _timeoutTimer;
  int _callDuration = 0;
  bool _noAnswer = false;

  @override
  void initState() {
    super.initState();
    _remoteUid = widget.remoteUid;
    _isCameraOff = !widget.isVideo;
    _initAgora();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_remoteUid == null && mounted) {
        setState(() => _noAnswer = true);
        // Notify backend of missed call
        ApiService.handleCallAction(widget.channelName, widget.channelName, 'missed');
        Future.delayed(const Duration(seconds: 2), _endCall);
      }
    });
  }

  Future<void> _initAgora() async {
    final callService = CallService();
    await callService.init();

    callService.engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user joined: ${connection.localUid}");
          setState(() => _localUserJoined = true);
          CallService().setInCall(true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user joined: $remoteUid");
          _timeoutTimer?.cancel();
          setState(() {
            _remoteUid = remoteUid;
          });
          _startTimer();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Remote user offline: $remoteUid");
          _endCall();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("Left channel");
        },
      ),
    );

    await callService.joinChannel(
      channelName: widget.channelName,
      token: widget.token,
      uid: widget.uid,
      isVideo: widget.isVideo,
    );
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    _timeoutTimer?.cancel();
    CallService().setInCall(false);
    await CallService().leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    CallService().muteLocalAudio(_isMuted);
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    CallService().muteLocalVideo(_isCameraOff);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerPhone = !_isSpeakerPhone);
    CallService().engine?.setEnableSpeakerphone(_isSpeakerPhone);
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09121F),
      body: Stack(
        children: [
          // Remote Video (Full Screen)
          _buildRemoteVideo(),
          
          // Local Video (Small Overlay)
          if (widget.isVideo && !_isCameraOff)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: CallService().engine!,
                      canvas: const VideoCanvas(uid: 0), // 0 means local
                    ),
                  ),
                ),
              ),
            ),

          // User Info & Status
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_remoteUid == null || !widget.isVideo) ...[
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white10,
                    backgroundImage: widget.callerPic.isNotEmpty ? NetworkImage(widget.callerPic) : null,
                    child: widget.callerPic.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  widget.callerName,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _noAnswer 
                      ? 'No Answer' 
                      : (_remoteUid == null ? 'Calling...' : _formatDuration(_callDuration)),
                  style: GoogleFonts.outfit(color: _noAnswer ? Colors.redAccent : Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          // Controls
          Positioned(
            bottom: 60,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  onPressed: _toggleMute,
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.redAccent : Colors.white10,
                ),
                _buildControlButton(
                  onPressed: _endCall,
                  icon: Icons.call_end,
                  color: Colors.redAccent,
                  large: true,
                ),
                if (widget.isVideo)
                  _buildControlButton(
                    onPressed: _toggleCamera,
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOff ? Colors.redAccent : Colors.white10,
                  )
                else
                  _buildControlButton(
                    onPressed: _toggleSpeaker,
                    icon: _isSpeakerPhone ? Icons.volume_up : Icons.volume_off,
                    color: _isSpeakerPhone ? Colors.white10 : Colors.blueAccent,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (widget.isVideo && _remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: CallService().engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
    return Container(color: const Color(0xFF09121F));
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    bool large = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(large ? 20 : 15),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: large ? 32 : 24),
      ),
    );
  }
}
