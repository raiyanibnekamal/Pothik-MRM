import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStore {
  SecureStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _user = 'user_profile';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<void> saveUser(UserProfile user) async {
    await _storage.write(key: _user, value: jsonEncode(user.toJson()));
  }

  Future<UserProfile?> readUser() async {
    final raw = await _storage.read(key: _user);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> get access => _storage.read(key: _access);
  Future<String?> get refresh => _storage.read(key: _refresh);

  Future<void> clearTokens() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _user);
  }
}

class PrefsStore {
  PrefsStore(this._p);
  final SharedPreferences _p;

  static Future<PrefsStore> create() async =>
      PrefsStore(await SharedPreferences.getInstance());

  String get language => _p.getString('language') ?? 'bn';
  Future<void> setLanguage(String v) => _p.setString('language', v);

  bool get batterySaver => _p.getBool('battery_saver') ?? false;
  Future<void> setBatterySaver(bool v) => _p.setBool('battery_saver', v);
}
