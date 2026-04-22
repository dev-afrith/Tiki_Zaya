import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  String? _currentCallId;

  Future<void> showIncomingCall({
    required String callerName,
    required String callType,
    required String callerPic,
    required String channelName,
    required String agoraToken,
    required String receiverUid,
    required String callerId,
  }) async {
    _currentCallId = const Uuid().v4();
    
    final params = CallKitParams(
      id: _currentCallId!,
      nameCaller: callerName,
      appName: 'Tiki Zaya',
      avatar: callerPic,
      handle: callType == 'video' ? 'Video Call' : 'Voice Call',
      type: callType == 'video' ? 1 : 0, // 0: audio, 1: video
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{
        'channelName': channelName,
        'agoraToken': agoraToken,
        'receiverUid': receiverUid,
        'callType': callType,
        'callerId': callerId,
      },
      headers: <String, dynamic>{'apiKey': 'AbcTest', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#09121F',
        backgroundUrl: 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: true,
        supportsUngrouping: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endCall(String? id) async {
    await FlutterCallkitIncoming.endCall(id ?? _currentCallId ?? '');
    _currentCallId = null;
  }

  static Stream<CallEvent?> get onEvent => FlutterCallkitIncoming.onEvent;
}
