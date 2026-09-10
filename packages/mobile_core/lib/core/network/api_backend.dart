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
      await _dio.post('$baseUrl/auth/otp/request', data: {'phone': _toE164(phone)});
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
        'phone': _toE164(phone),
        'code': otp,
        'role': role.name,
      });
      final data = res.data['data'] as Map<String, dynamic>;
      access = data['access_token'] as String?;
      refresh = data['refresh_token'] as String?;
      final user = data['user'] as Map<String, dynamic>;
      final apiPhone = user['phone'] as String?;
      sessionUser = UserProfile(
        id: user['id'] as String,
        phone: apiPhone != null ? BdPhone.display(apiPhone) : phone,
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
  Future<SosAlert> triggerSos({required bool allowed}) async {
    if (!allowed) {
      throw ApiException(
        code: ErrorCodes.sosNotAllowed,
        message: 'রাইড চলাকালীনই SOS ব্যবহার করা যাবে।',
        status: 403,
      );
    }
    if (access == null) {
      throw ApiException(code: ErrorCodes.unauthorized, message: 'Unauthorized', status: 401);
    }
    if (activeSos != null && activeSos!.status == 'active') {
      return activeSos!;
    }

    final ride = activeRide;
    try {
      final res = await _dio.post(
        '$baseUrl/sos/trigger',
        data: {
          if (ride != null) 'ride_id': ride.id,
          if (ride != null) 'lat': ride.pickup.latitude,
          if (ride != null) 'lng': ride.pickup.longitude,
          'trigger_type': 'hold',
        },
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      final row = res.data['data'] as Map<String, dynamic>;
      final trackUrl = await _resolveTrackUrl(ride);
      activeSos = _mapSosAlert(row, trackUrl);
      return activeSos!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> cancelSos() async {
    final alert = activeSos;
    if (alert == null) return;
    if (access == null) {
      throw ApiException(code: ErrorCodes.unauthorized, message: 'Unauthorized', status: 401);
    }
    try {
      await _dio.post(
        '$baseUrl/sos/${alert.id}/cancel',
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      activeSos = null;
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

  Future<String> _resolveTrackUrl(Ride? ride) async {
    if (ride == null) return '';
    final cached = ride.shareUrl;
    if (cached != null && cached.isNotEmpty) return cached;
    if (access == null) return '';

    try {
      final res = await _dio.get(
        '$baseUrl/rides/${ride.id}/share-link',
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final url = data['url'] as String? ?? '';
      if (url.isNotEmpty && activeRide?.id == ride.id) {
        activeRide = activeRide!.copyWith(shareUrl: url);
      }
      return url;
    } on DioException {
      return '';
    }
  }

  SosAlert _mapSosAlert(Map<String, dynamic> row, String trackUrl) {
    return SosAlert(
      id: row['id'] as String,
      status: row['status'] as String,
      trackUrl: trackUrl,
      smsStatus: row['sms_status'] as String? ?? 'pending',
    );
  }

  /// Converts [accountPhone] local output to Laravel E.164 (+8801XXXXXXXXX).
  String _toE164(String local) {
    if (BdPhone.isQa(local)) return '+880152170004';
    var d = BdPhone.digits(local);
    if (d.startsWith('880')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return '+880$d';
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
