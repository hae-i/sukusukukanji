import 'package:flutter/services.dart';

abstract interface class AppIconService {
  Future<bool> isSupported();
  Future<String> current();
  Future<void> apply(String iconKey);
}

/// Used in environments without a launcher. Production mobile uses the channel.
class UnsupportedAppIconService implements AppIconService {
  const UnsupportedAppIconService();
  @override
  Future<bool> isSupported() async => false;
  @override
  Future<String> current() async => 'grade1';
  @override
  Future<void> apply(String iconKey) async =>
      throw UnsupportedError('Launcher icons are unavailable');
}

class PlatformAppIconService implements AppIconService {
  const PlatformAppIconService();
  static const channel = MethodChannel('sukusukukanji/app_icon');
  @override
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String> current() async =>
      await channel.invokeMethod<String>('current') ?? 'grade1';
  @override
  Future<void> apply(String iconKey) async {
    if (!RegExp(r'^grade[1-6]$').hasMatch(iconKey)) {
      throw ArgumentError('Unknown icon');
    }
    await channel.invokeMethod<void>('apply', {'iconKey': iconKey});
  }
}
