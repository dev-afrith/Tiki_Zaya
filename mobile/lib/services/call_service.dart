import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:mobile/services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInCall = false;

  bool get isInCall => _isInCall;
  void setInCall(bool value) => _isInCall = value;

  // Change these to your actual Agora App ID
  String get appId => "YOUR_AGORA_APP_ID"; 

  Future<void> init() async {
    if (_isInitialized) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await _engine!.enableVideo();
    await _engine!.startPreview();
    
    _isInitialized = true;
  }

  Future<bool> handlePermissions(bool isVideo) async {
    final status = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    return status.values.every((s) => s.isGranted);
  }

  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int uid,
    required bool isVideo,
  }) async {
    await init();
    
    if (isVideo) {
      await _engine!.enableVideo();
    } else {
      await _engine!.disableVideo();
    }

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    await _engine?.stopPreview();
    // We don't release the engine entirely to allow quick restarts
  }

  RtcEngine? get engine => _engine;

  Future<void> muteLocalAudio(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> muteLocalVideo(bool mute) async {
    await _engine?.muteLocalVideoStream(mute);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }
}
