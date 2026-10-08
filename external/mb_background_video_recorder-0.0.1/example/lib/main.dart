import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mb_background_video_recorder/mb_bvr.dart';
import 'package:mb_background_video_recorder/mb_bvr_platform_interface.dart';
import 'package:mb_background_video_recorder_example/shared_preferences_helper.dart';

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

  // Check if the recorder is already recording when returning to the app after it was closed.
  Future<void> getInitialRecordingStatus() async {
    _isRecording =
        await _flutterBackgroundVideoRecorderPlugin.getVideoRecordingStatus() ==
            1;
  }

  // Listen to recorder events to update UI accordingly
  // Switch values are according to the StreamSubscription documentation above
  void listenRecordingState() {
    _streamSubscription =
        _flutterBackgroundVideoRecorderPlugin.recorderState.listen((event) {
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
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'MB BVR',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  " $cameraFacing",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              ElevatedButton(
                style: ButtonStyle(
                    fixedSize: WidgetStateProperty.all(const Size(100, 100)),
                    backgroundColor: WidgetStateProperty.all(Colors.white),
                    shape: WidgetStateProperty.all<OutlinedBorder>(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)))),
                onPressed: () async {
                  if (!_isRecording && !_recorderBusy) {
                    if (cameraFacing == "Rear camera") {
                      cameraFacing = "Front camera";
                    } else {
                      cameraFacing = "Rear camera";
                    }

                    SharedPreferencesHelper.setCamera(val: cameraFacing);

                    setState(() {});
                  }
                },
                child: const Icon(
                  Icons.camera_front,
                  color: Colors.blue,
                  size: 50,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                style: ButtonStyle(
                    fixedSize: WidgetStateProperty.all(const Size(100, 100)),
                    backgroundColor: WidgetStateProperty.all(Colors.white),
                    shape: WidgetStateProperty.all<OutlinedBorder>(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)))),
                onPressed: () async {
                  SharedPreferencesHelper.setVideoStatus(val: !_isRecording);

                  if (!_isRecording && !_recorderBusy) {
                    await _flutterBackgroundVideoRecorderPlugin
                        .startVideoRecording(
                            folderName: "Example Recorder",
                            cameraFacing: cameraFacing == "Rear camera"
                                ? CameraFacing.rearCamera
                                : CameraFacing.frontCamera,
                            notificationTitle: "Example Notification Title",
                            notificationText: "Example Notification Text",
                            showToast: false);
                    setState(() {});
                  } else if (!_isRecording && _recorderBusy) {
                    return;
                  } else {
                    String filePath =
                        await _flutterBackgroundVideoRecorderPlugin
                                .stopVideoRecording() ??
                            "None";
                    setState(() {});
                    debugPrint(filePath);
                  }
                },
                child: _isRecording
                    ? const Icon(
                        Icons.pause,
                        color: Colors.red,
                        size: 55,
                      )
                    : const Icon(
                        Icons.play_arrow,
                        color: Colors.green,
                        size: 55,
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class OverlayPermission {
  static const MethodChannel _channel = MethodChannel('overlay_permission');

  static Future<bool> checkPermission() async {
    final bool isGranted =
        await _channel.invokeMethod('isOverlayPermissionGranted');
    return isGranted;
  }

  static Future<void> requestPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }
}
