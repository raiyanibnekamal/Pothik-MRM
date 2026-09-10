import 'package:flutter/services.dart';

/// Native driver GPS. Background updates live in Kotlin/Swift, not a Flutter plugin.
class GpsChannel {
  static const _methods = MethodChannel('com.bdrideshare/gps');
  static const events = EventChannel('com.bdrideshare/gps_events');

  static Future<void> ensureReady() async {
    try {
      await _methods.invokeMethod<void>('warmUp');
    } on MissingPluginException {
      // Simulator / first run without native service bound.
    }
  }

  static Future<void> start({required bool batterySaver}) async {
    try {
      await _methods.invokeMethod<void>('start', {
        'intervalMs': batterySaver ? 15000 : 3000,
        'displacementM': 10,
      });
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stop');
    } on MissingPluginException {
      return;
    }
  }
}
