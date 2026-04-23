import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../repositories/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _autoCapture;
  late bool _vibration;
  late bool _shutterSound;
  late bool _ocr;
  late int _imageQuality;

  @override
  void initState() {
    super.initState();
    final s = SettingsRepository.instance;
    _autoCapture = s.autoCaptureEnabled;
    _vibration = s.vibrationEnabled;
    _shutterSound = s.shutterSoundEnabled;
    _ocr = s.ocrEnabled;
    _imageQuality = s.imageQuality;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark mode'),
            value: isDark,
            onChanged: (value) async {
              ref.read(themeModeProvider.notifier).state = value;
              await SettingsRepository.instance.setDarkMode(value);
            },
          ),
          SwitchListTile(
            title: const Text('Auto capture'),
            value: _autoCapture,
            onChanged: (value) async {
              setState(() => _autoCapture = value);
              await SettingsRepository.instance.setAutoCaptureEnabled(value);
            },
          ),
          SwitchListTile(
            title: const Text('Vibration feedback'),
            value: _vibration,
            onChanged: (value) async {
              setState(() => _vibration = value);
              await SettingsRepository.instance.setVibrationEnabled(value);
            },
          ),
          SwitchListTile(
            title: const Text('Shutter sound'),
            value: _shutterSound,
            onChanged: (value) async {
              setState(() => _shutterSound = value);
              await SettingsRepository.instance.setShutterSoundEnabled(value);
            },
          ),
          SwitchListTile(
            title: const Text('OCR (experimental)'),
            value: _ocr,
            onChanged: (value) async {
              setState(() => _ocr = value);
              await SettingsRepository.instance.setOcrEnabled(value);
            },
          ),
          ListTile(
            title: const Text('Image quality'),
            subtitle: Text('$_imageQuality'),
            trailing: DropdownButton<int>(
              value: _imageQuality,
              items: const [60, 75, 85, 95]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _imageQuality = value);
                await SettingsRepository.instance.setImageQuality(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
