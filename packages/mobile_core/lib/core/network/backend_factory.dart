import 'package:mobile_core/core/network/api_backend.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

/// Backend selection.
///
/// Local development (no backend):
///   `flutter run`
///
/// Local emulator + Laravel dev server:
///   `flutter run --dart-define=USE_API=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
///
/// S0.5 / S1.6 — Production/staging build (REQUIRED):
///   `flutter build apk --release --dart-define=USE_API=true --dart-define=API_BASE_URL=https://api.YOURDOMAIN/api/v1`
///
/// When `USE_API=false` (the default), the in-memory `MockBackend` is used.
/// Mock rides never touch Laravel, never send real SMS, and never persist.
/// A release build with `USE_API=false` would silently simulate rides, so
/// the production release pipeline MUST pass `--dart-define=USE_API=true`.
MockBackend createBackend() {
  const useApi = bool.fromEnvironment('USE_API', defaultValue: false);
  if (useApi) {
    return ApiBackend();
  }
  return MockBackend();
}
