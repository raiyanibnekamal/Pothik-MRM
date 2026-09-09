import 'package:dio/dio.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

/// HTTP backend — auth + profile wired to Laravel API; ride flows fall back to mock simulation until socket dispatch ships.
class ApiBackend extends MockBackend {
  ApiBackend({String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000/api/v1',
        ),
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        ));

  final String baseUrl;
  final Dio _dio;

  @override
  Future<void> requestOtp(String input, {required bool online}) async {
    if (!online) {
      throw ApiException(code: ErrorCodes.smsDown, message: 'SMS পাঠানো যাচ্ছে না।');
    }
    final phone = accountPhone(input);
    try {
      await _dio.post('$baseUrl/auth/otp/request', data: {'phone': phone});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<UserProfile> verifyOtp({
    required String national10,
    required String otp,
    required AppRole role,
  }) async {
    final phone = accountPhone(national10);
    try {
      final res = await _dio.post('$baseUrl/auth/otp/verify', data: {
        'phone': phone,
        'code': otp,
        'role': role.name,
      });
      final data = res.data['data'] as Map<String, dynamic>;
      access = data['access_token'] as String?;
      refresh = data['refresh_token'] as String?;
      final user = data['user'] as Map<String, dynamic>;
      sessionUser = UserProfile(
        id: user['id'] as String,
        phone: user['phone'] as String? ?? phone,
        name: user['name'] as String?,
        role: role,
        onboarding: role == AppRole.driver
            ? DriverOnboardingStatus.phoneVerified
            : DriverOnboardingStatus.approved,
        locationPrimed: user['is_profile_complete'] == true,
      );
      return sessionUser!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<UserProfile> patchProfile({
    String? name,
    String? email,
    bool? locationPrimed,
    DriverOnboardingStatus? onboarding,
  }) async {
    if (access == null) {
      throw ApiException(code: ErrorCodes.unauthorized, message: 'Unauthorized', status: 401);
    }
    try {
      final res = await _dio.patch(
        '$baseUrl/profile',
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (locationPrimed == true) 'language': 'bn',
        },
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      final user = res.data['data'] as Map<String, dynamic>;
      sessionUser = (sessionUser ?? UserProfile(id: user['id'] as String, phone: user['phone'] as String, role: AppRole.passenger))
          .copyWith(
        name: user['name'] as String?,
        email: user['email'] as String?,
        locationPrimed: locationPrimed ?? sessionUser?.locationPrimed ?? false,
        onboarding: onboarding ?? sessionUser?.onboarding,
      );
      return sessionUser!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      return ApiException(
        code: err['code'] as String? ?? ErrorCodes.validationError,
        message: err['message'] as String? ?? 'Request failed',
        status: e.response?.statusCode ?? 400,
      );
    }
    return ApiException(
      code: ErrorCodes.validationError,
      message: e.message ?? 'Network error',
      status: e.response?.statusCode ?? 500,
    );
  }
}
