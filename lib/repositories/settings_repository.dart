import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  SettingsRepository._internal();
  static final SettingsRepository instance = SettingsRepository._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme
  bool get isDarkMode => _prefs.getBool('dark_mode') ?? false;
  Future<void> setDarkMode(bool value) => _prefs.setBool('dark_mode', value);

  // Capture sensitivity: 1=low, 2=medium, 3=high
  int get captureSensitivity => _prefs.getInt('capture_sensitivity') ?? 2;
  Future<void> setCaptureSensitivity(int value) =>
      _prefs.setInt('capture_sensitivity', value);

  // Image quality: 60, 75, 85, 95
  int get imageQuality => _prefs.getInt('image_quality') ?? 85;
  Future<void> setImageQuality(int value) =>
      _prefs.setInt('image_quality', value);

  // Vibration
  bool get vibrationEnabled => _prefs.getBool('vibration_enabled') ?? true;
  Future<void> setVibrationEnabled(bool value) =>
      _prefs.setBool('vibration_enabled', value);

  // Shutter sound
  bool get shutterSoundEnabled => _prefs.getBool('shutter_sound') ?? true;
  Future<void> setShutterSoundEnabled(bool value) =>
      _prefs.setBool('shutter_sound', value);

  // OCR toggle
  bool get ocrEnabled => _prefs.getBool('ocr_enabled') ?? false;
  Future<void> setOcrEnabled(bool value) =>
      _prefs.setBool('ocr_enabled', value);

  // PDF compression: 0=none, 1=low, 2=medium, 3=high
  int get pdfCompression => _prefs.getInt('pdf_compression') ?? 2;
  Future<void> setPdfCompression(int value) =>
      _prefs.setInt('pdf_compression', value);

  // Auto capture
  bool get autoCaptureEnabled => _prefs.getBool('auto_capture') ?? true;
  Future<void> setAutoCaptureEnabled(bool value) =>
      _prefs.setBool('auto_capture', value);

  // Storage path preference
  String get storageFolder =>
      _prefs.getString('storage_folder') ?? 'FlipScan';
  Future<void> setStorageFolder(String value) =>
      _prefs.setString('storage_folder', value);
}
