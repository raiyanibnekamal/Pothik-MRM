import 'package:mobile_core/core/network/api_backend.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

/// `flutter run --dart-define=USE_API=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
MockBackend createBackend() {
  const useApi = bool.fromEnvironment('USE_API', defaultValue: false);
  if (useApi) {
    return ApiBackend();
  }
  return MockBackend();
}
