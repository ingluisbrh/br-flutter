import 'dart:core';

import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  // Shared Preference Keys
  static SharedPreferences? _prefs;

  static const String _videoRecordingInprogress = 'recordingInProgress';
  static const String _selectedCamera = 'selectedCamera';

  static bool videoRecordingInProgress = false;
  static String selectedCamera = "Rear camera";

  // Load saved data...
  static Future<void> loadSavedData() async {
    _prefs = await SharedPreferences.getInstance();
    getStatusOfVideoRecording();
    fetchCamera();
  }

  //!------------------------------------------------- Video recording inprogress status --------------------------------------------------//
  static void setVideoStatus({required bool val}) {
    videoRecordingInProgress = val;
    _prefs?.setBool(_videoRecordingInprogress, val);
  }

  static bool get getVideoStatus {
    getStatusOfVideoRecording();
    return _prefs?.getBool(_videoRecordingInprogress) ?? false;
  }

  static Future<void> getStatusOfVideoRecording() async {
    videoRecordingInProgress =
        _prefs?.getBool(_videoRecordingInprogress) ?? false;
  }

  //!------------------------------------------------- Selected camera --------------------------------------------------//
  static void setCamera({required String val}) {
    selectedCamera = val;
    _prefs?.setString(_selectedCamera, val);
  }

  static String get getCamera {
    fetchCamera();
    return _prefs?.getString(_selectedCamera) ?? "Rear camera";
  }

  static Future<void> fetchCamera() async {
    selectedCamera = _prefs?.getString(_selectedCamera) ?? "Rear camera";
  }
}
