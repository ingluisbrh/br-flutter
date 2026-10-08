import 'dart:async';

import 'package:background_recorder/shared_prefences_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mb_background_video_recorder/mb_bvr.dart';
import 'package:mb_background_video_recorder/mb_bvr_platform_interface.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesHelper.loadSavedData();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SharedPreferencesHelper sharedPreferencesHelper = SharedPreferencesHelper();

  // Unified folder name for all video recordings to avoid conflicts
  static const String _videoFolderName = "data";

  // Recorder variables to keep track of recording status
  // _isRecording when set to true indicates that the video is being recorded
  // _recorderBusy when set to true indicated that the recorder is doing some job
  //    - It can be that the recorder is initializing resources
  //    - And/or recorder is recording the video.
  // In any case, when the _recorderBusy is set to true, start/stop recording should not be called.
  bool _isRecording = false;
  bool _recorderBusy = false;

  // StreamSubscription to get realtime recorder events from native platform
  //  - 1: Recording in progress
  //  - 2: Recording has been stopped
  //  - 3: Recorder is being initialized and about to start recording
  //  - -1: Recorder encountered an error
  StreamSubscription<int?>? _streamSubscription;
  final _flutterBackgroundVideoRecorderPlugin =
      FlutterBackgroundVideoRecorder();

  late final MethodChannel _volumeChannel = const MethodChannel(
    'volume_buttons',
  );

  late final MethodChannel _remoteTriggerChannel = const MethodChannel(
    'remote_trigger',
  );

  // Indicates which camera to use for recording
  // Can take values:
  //  - Rear camera
  //  - Front camera
  String cameraFacing = "Rear camera";

  @override
  void initState() {
    super.initState();
    getInitialRecordingStatus();
    listenRecordingState();
    _volumeChannel.setMethodCallHandler(_handleVolumePress);
    _remoteTriggerChannel.setMethodCallHandler(_handleRemoteTrigger);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);

    _isRecording = SharedPreferencesHelper.videoRecordingInProgress;
    _recorderBusy = _isRecording;
    cameraFacing = SharedPreferencesHelper.selectedCamera;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleVolumePress(MethodCall call) async {
    switch (call.method) {
      case 'start':
        SharedPreferencesHelper.setVideoStatus(val: true);
        if (!_isRecording && !_recorderBusy) {
          await _flutterBackgroundVideoRecorderPlugin.startVideoRecording(
            folderName: _videoFolderName,
            cameraFacing: cameraFacing == "Rear camera"
                ? CameraFacing.rearCamera
                : CameraFacing.frontCamera,
            notificationTitle: "Example Notification Title",
            notificationText: "Example Notification Text",
            showToast: false,
          );
        }
        break;
      case 'stop':
        SharedPreferencesHelper.setVideoStatus(val: false);
        if (_isRecording) {
          String filePath =
              await _flutterBackgroundVideoRecorderPlugin
                  .stopVideoRecording() ??
              "None";
          debugPrint(filePath);
        }
        break;
    }
  }

  // Handle remote trigger events from PhoneCallReceiver (silent call)
  Future<void> _handleRemoteTrigger(MethodCall call) async {
    switch (call.method) {
      case 'call_trigger':
        final Map<dynamic, dynamic> args =
            call.arguments as Map<dynamic, dynamic>;
        final String action = args['action'] as String? ?? '';
        final String triggerType = args['type'] as String? ?? 'unknown';
        final String phoneNumber = args['number'] as String? ?? 'unknown';

        debugPrint(
          'Remote trigger received: type=$triggerType, number=$phoneNumber, action=$action',
        );

        if (action == 'start') {
          SharedPreferencesHelper.setVideoStatus(val: true);
          if (!_isRecording && !_recorderBusy) {
            await _flutterBackgroundVideoRecorderPlugin.startVideoRecording(
              folderName: _videoFolderName,
              cameraFacing: cameraFacing == "Rear camera"
                  ? CameraFacing.rearCamera
                  : CameraFacing.frontCamera,
              notificationTitle: "Remote Recording Started",
              notificationText: "Recording triggered by call from $phoneNumber",
              showToast: false,
            );
          }
        } else if (action == 'stop') {
          SharedPreferencesHelper.setVideoStatus(val: false);
          if (_isRecording) {
            String filePath =
                await _flutterBackgroundVideoRecorderPlugin
                    .stopVideoRecording() ??
                "None";
            debugPrint('Remote recording stopped. File: $filePath');
          }
        }
        break;
    }
  }

  // Check if the recorder is already recording when returning to the app after it was closed.
  Future<void> getInitialRecordingStatus() async {
    _isRecording =
        await _flutterBackgroundVideoRecorderPlugin.getVideoRecordingStatus() ==
        1;
  }

  // Listen to recorder events to update UI accordingly
  // Switch values are according to the StreamSubscription documentation above
  void listenRecordingState() {
    _streamSubscription = _flutterBackgroundVideoRecorderPlugin.recorderState
        .listen((event) {
          switch (event) {
            case 1:
              _isRecording = true;
              _recorderBusy = true;
              setState(() {});
              break;
            case 2:
              _isRecording = false;
              _recorderBusy = false;
              setState(() {});
              break;
            case 3:
              _recorderBusy = true;
              setState(() {});
              break;
            case -1:
              _isRecording = false;
              setState(() {});
              break;
            default:
              return;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ClockWidget(
          isRecording: _isRecording,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!_isRecording && !_recorderBusy) {
      SharedPreferencesHelper.setVideoStatus(val: true);
      await _flutterBackgroundVideoRecorderPlugin.startVideoRecording(
        folderName: _videoFolderName,
        cameraFacing: cameraFacing == "Rear camera"
            ? CameraFacing.rearCamera
            : CameraFacing.frontCamera,
        notificationTitle: "Recording Started",
        notificationText: "Recording in progress",
        showToast: false,
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      SharedPreferencesHelper.setVideoStatus(val: false);
      String filePath =
          await _flutterBackgroundVideoRecorderPlugin.stopVideoRecording() ??
          "None";
      debugPrint(filePath);
    }
  }
}

class ClockWidget extends StatefulWidget {
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final bool isRecording;

  const ClockWidget({
    super.key,
    this.onStartRecording,
    this.onStopRecording,
    this.isRecording = false,
  });

  @override
  ClockWidgetState createState() => ClockWidgetState();
}

class ClockWidgetState extends State<ClockWidget> {
  late Timer _timer;
  late String _timeString;
  bool _isClockVisible = true;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatted =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _timeString = formatted;
    });
  }

  void _toggleClockVisibility() {
    setState(() {
      _isClockVisible = !_isClockVisible;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;

    if (x < width / 3) {
      widget.onStopRecording?.call();
    } else if (x < 2 * width / 3) {
      _toggleClockVisibility();
    } else {
      widget.onStartRecording?.call();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTapUp,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: Center(
          child: _isClockVisible
              ? Text(
                  _timeString,
                  style: TextStyle(
                    color: Color(0xFF005500),
                    fontSize: 150,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : SizedBox.shrink(),
        ),
      ),
    );
  }
}

class OverlayPermission {
  static const MethodChannel _channel = MethodChannel('overlay_permission');

  static Future<bool> checkPermission() async {
    final bool isGranted = await _channel.invokeMethod(
      'isOverlayPermissionGranted',
    );
    return isGranted;
  }

  static Future<void> requestPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }
}
