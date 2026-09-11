import 'dart:async';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
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
        )) {
    _dio.interceptors.add(_AuthInterceptor());
    _instance = this;
  }

  final String baseUrl;
  final Dio _dio;

  Completer<void>? _refreshing;
  EarningsToday? _cachedEarnings;
  List<VehicleType> _cachedTypes = const [];

  /// Static handle that the global auth interceptor reads. Always the most
  /// recently constructed [ApiBackend] (we only have one per app session).
  static ApiBackend? _instance;
  static String? _peekAccess() => _instance?.access;
  static Future<void> _refreshGlobal() => _instance?.refreshAccessToken() ?? Future<void>.value();

  /// Public accessor for callers that hold a [MockBackend] but need to detect
  /// the active API implementation (onboarding / profile screens).
  static ApiBackend? peek() => _instance;

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
        id: user['id']?.toString() ?? 'u_$phone',
        phone: apiPhone != null ? BdPhone.display(apiPhone) : phone,
        name: user['name'] as String?,
        email: user['email'] as String?,
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
          'name': ?name,
          'email': ?email,
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

  // ───────────────────────── Auth ─────────────────────────
  Future<UserProfile> fetchProfile() async {
    await _requireAuth();
    try {
      final res = await _dio.get('$baseUrl/profile', options: _authOpts());
      return _mapProfile(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<void>();
    _refreshing = completer;
    try {
      if (refresh == null) {
        throw ApiException(code: ErrorCodes.unauthorized, message: 'Unauthorized', status: 401);
      }
      final res = await _dio.post(
        '$baseUrl/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      access = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      if (newRefresh != null) refresh = newRefresh;
      completer.complete();
    } on DioException catch (e) {
      access = null;
      refresh = null;
      completer.completeError(_mapError(e));
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  // ──────────────────────── Vehicle types ────────────────────────
  Future<List<VehicleType>> fetchVehicleTypes({bool force = false}) async {
    if (!force && _cachedTypes.isNotEmpty) return _cachedTypes;
    try {
      final res = await _dio.get('$baseUrl/rides/vehicle-types');
      final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
      _cachedTypes = list.map(_mapVehicleType).toList(growable: false);
      return _cachedTypes;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<int> fetchEstimate({
    required String vehicleCode,
    required LatLng pickup,
    required LatLng drop,
  }) async {
    await fetchVehicleTypes();
    final id = _vehicleTypeId(vehicleCode);
    try {
      final res = await _dio.post('$baseUrl/rides/estimate', data: {
        if (id != null) 'vehicle_type_id': id else 'vehicle_type': vehicleCode,
        'pickup_lat': pickup.latitude,
        'pickup_lng': pickup.longitude,
        'drop_lat': drop.latitude,
        'drop_lng': drop.longitude,
      });
      return (res.data['data']['estimated_fare'] as num).round();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ───────────────────────── Rides (real API) ─────────────────────────
  Future<Ride> createRideApi({
    required String vehicleCode,
    required LatLng pickup,
    required String pickupAddress,
    required LatLng drop,
    required String dropAddress,
    required String paymentMethod,
  }) async {
    await _requireAuth();
    await fetchVehicleTypes();
    final id = _vehicleTypeId(vehicleCode);
    try {
      final res = await _dio.post('$baseUrl/rides', data: {
        if (id != null) 'vehicle_type_id': id else 'vehicle_type': vehicleCode,
        'pickup_lat': pickup.latitude,
        'pickup_lng': pickup.longitude,
        'pickup_address': pickupAddress,
        'drop_lat': drop.latitude,
        'drop_lng': drop.longitude,
        'drop_address': dropAddress,
        'payment_method': paymentMethod,
      }, options: _authOpts());
      final data = res.data['data'] as Map<String, dynamic>;
      activeRide = _mapRide(data, _resolveType(data['vehicle_type'] ?? vehicleCode));
      return activeRide!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Polls the active ride until a driver is matched or [timeout] elapses.
  Future<Ride?> matchDemoApi({
    required String rideId,
    required Duration timeout,
  }) async {
    await _requireAuth();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await _dio.get(
          '$baseUrl/rides/$rideId',
          options: _authOpts(),
        );
        final j = res.data['data'] as Map<String, dynamic>;
        final ride = _mapRide(j, _resolveType(j['vehicle_type'] ?? 'CAR'));
        activeRide = ride;
        final s = ride.status;
        if (s == RideStatus.accepted ||
            s == RideStatus.driverArriving ||
            s == RideStatus.driverArrived ||
            s == RideStatus.inProgress) {
          return ride;
        }
        if (s == RideStatus.cancelled || s == RideStatus.completed) {
          return ride;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) throw _mapError(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return activeRide;
  }

  /// S1.3 — Hydrates the inherited [history] list from `GET /rides`.
  /// Replaces the mock backend's in-memory list with the server's record
  /// for the authenticated user. Safe to call on every screen mount;
  /// failures leave the previous list intact.
  Future<List<Ride>> refreshHistory() async {
    await _requireAuth();
    try {
      final res = await _dio.get('$baseUrl/rides', options: _authOpts());
      final data = res.data['data'];
      final items = <Map<String, dynamic>>[];
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) items.add(e);
        }
      } else if (data is Map && data['data'] is List) {
        for (final e in (data['data'] as List)) {
          if (e is Map<String, dynamic>) items.add(e);
        }
      }
      final rides = <Ride>[];
      for (final j in items) {
        final type = _resolveType(j['vehicle_type'] ?? 'CAR');
        try {
          rides.add(_mapRide(j, type));
        } on Object {
          // Skip malformed entries so a single bad row doesn't kill history.
        }
      }
      history
        ..clear()
        ..addAll(rides);
      return rides;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Refreshes [activeRide] from the server and returns the current state.
  Future<Ride?> advanceApi({String? rideId}) async {
    await _requireAuth();
    final id = rideId ?? activeRide?.id;
    if (id == null) return null;
    try {
      final res = await _dio.get('$baseUrl/rides/$id', options: _authOpts());
      final j = res.data['data'] as Map<String, dynamic>;
      final type = _resolveType(j['vehicle_type'] ?? activeRide?.vehicleType.code ?? 'CAR');
      activeRide = _mapRide(j, type);
      return activeRide;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Ride> cancelRide(String rideId, {String? reason}) async {
    await _requireAuth();
    try {
      final res = await _dio.post(
        '$baseUrl/rides/$rideId/cancel',
        data: {'reason': ?reason},
        options: _authOpts(),
      );
      final j = res.data['data'] as Map<String, dynamic>;
      final type = _resolveType(j['vehicle_type'] ?? activeRide?.vehicleType.code ?? 'CAR');
      activeRide = _mapRide(j, type);
      return activeRide!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> rateRide({
    required String rideId,
    required int stars,
    String? comment,
  }) async {
    await _requireAuth();
    try {
      await _dio.post(
        '$baseUrl/rides/$rideId/rate',
        data: {'score': stars, 'comment': ?comment},
        options: _authOpts(),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> confirmCash(int amount) async {
    final ride = activeRide;
    if (ride == null) return;
    await _requireAuth();
    try {
      await _dio.post(
        '$baseUrl/rides/${ride.id}/cash-confirm',
        data: {'amount_collected': amount},
        options: _authOpts(),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Remote variant of `completeAndRate` that rates a ride on the API.
  Future<void> rateRideApi({
    required String rideId,
    required int stars,
    String? comment,
  }) async {
    await rateRide(rideId: rideId, stars: stars, comment: comment);
  }

  // ──────────────────────── Guardians (remote) ────────────────────────
  Future<List<Guardian>> fetchGuardiansRemote() async {
    await _requireAuth();
    try {
      final res = await _dio.get(
        '$baseUrl/profile/emergency-contacts',
        options: _authOpts(),
      );
      final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
      return list.map((j) => Guardian(
            id: j['id'] as String,
            name: j['name'] as String,
            phone: _phoneFromE164(j['phone'] as String),
          )).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Guardian> addGuardianRemote({required String name, required String phone}) async {
    await _requireAuth();
    try {
      final res = await _dio.post(
        '$baseUrl/profile/emergency-contacts',
        data: {'name': name, 'phone': _toE164(phone)},
        options: _authOpts(),
      );
      final j = res.data['data'] as Map<String, dynamic>;
      return Guardian(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: _phoneFromE164(j['phone'] as String),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ──────────────────────── Driver onboarding ────────────────────────
  Future<Map<String, dynamic>> fetchOnboardingStatus() async {
    await _requireAuth();
    try {
      final res = await _dio.get('$baseUrl/driver/status', options: _authOpts());
      return (res.data['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> savePersonal({
    required String name,
    required String nid,
    required String dateOfBirth,
    required String address,
  }) async {
    await _requireAuth();
    try {
      await _dio.post('$baseUrl/driver/personal', data: {
        'name': name,
        'nid': nid,
        'date_of_birth': dateOfBirth,
        'address': address,
      }, options: _authOpts());
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> saveVehicle({
    required String vehicleType,
    required String plate,
    required String make,
    required String model,
    required String color,
    required int year,
    String? licenseDocUrl,
    String? vehicleDocUrl,
    String? selfieUrl,
  }) async {
    await _requireAuth();
    await fetchVehicleTypes();
    final id = _vehicleTypeId(vehicleType);
    try {
      await _dio.post('$baseUrl/driver/vehicle', data: {
        if (id != null) 'vehicle_type_id': id else 'vehicle_type': vehicleType,
        'plate_no': plate,
        'vehicle_make': make,
        'vehicle_model': model,
        'vehicle_color': color,
        'vehicle_year': year,
        'license_doc_url': ?licenseDocUrl,
        'vehicle_doc_url': ?vehicleDocUrl,
        'selfie_url': ?selfieUrl,
      }, options: _authOpts());
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> submitDriverForReview() async {
    await _requireAuth();
    try {
      await _dio.post('$baseUrl/driver/submit', options: _authOpts());
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ──────────────────────── Driver dispatch ────────────────────────
  Future<void> setDriverAvailability({required bool online}) async {
    await _requireAuth();
    try {
      await _dio.post(
        '$baseUrl/driver/availability',
        data: {'is_online': online},
        options: _authOpts(),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> postDriverLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    await _requireAuth();
    try {
      await _dio.post(
        '$baseUrl/driver/location',
        data: {
          'lat': lat,
          'lng': lng,
          'heading': ?heading,
          'speed': ?speed,
        },
        options: _authOpts(),
      );
    } on DioException catch (e) {
      // Don't throw on transient network blips — location is fire-and-forget.
      if (e.response?.statusCode != null && e.response!.statusCode! >= 500) return;
    }
  }

  Future<Ride?> acceptRide(String rideId) async {
    await _requireAuth();
    try {
      final res = await _dio.post(
        '$baseUrl/rides/$rideId/accept',
        options: _authOpts(),
      );
      final j = res.data['data'] as Map<String, dynamic>;
      final type = _resolveType(j['vehicle_type'] ?? activeRide?.vehicleType.code ?? 'CAR');
      final ride = _mapRide(j, type);
      activeRide = ride;
      return ride;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> declineRide(String rideId, {String? reason}) async {
    await _requireAuth();
    try {
      await _dio.post(
        '$baseUrl/rides/$rideId/decline',
        data: {'reason': ?reason},
        options: _authOpts(),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Ride> markArrived(String rideId) async {
    await _requireAuth();
    try {
      final res = await _dio.post(
        '$baseUrl/rides/$rideId/arrived',
        options: _authOpts(),
      );
      final j = res.data['data'] as Map<String, dynamic>;
      final type = _resolveType(j['vehicle_type'] ?? activeRide?.vehicleType.code ?? 'CAR');
      final ride = _mapRide(j, type);
      activeRide = ride;
      return ride;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Ride> verifyRidePin({required String rideId, required String pin}) async {
    await _requireAuth();
    try {
      final res = await _dio.post(
        '$baseUrl/rides/$rideId/pin/verify',
        data: {'pin': pin},
        options: _authOpts(),
      );
      final j = res.data['data'] as Map<String, dynamic>;
      final type = _resolveType(j['vehicle_type'] ?? activeRide?.vehicleType.code ?? 'CAR');
      final ride = _mapRide(j, type);
      activeRide = ride;
      return ride;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Poll for the next incoming ride for an online driver.
  Future<Ride?> pollForIncomingRequest({Duration timeout = const Duration(seconds: 10)}) async {
    await _requireAuth();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await _dio.get(
          '$baseUrl/driver/incoming',
          options: _authOpts(),
        );
        final data = res.data['data'];
        if (data is Map && data['ride'] is Map) {
          final j = data['ride'] as Map<String, dynamic>;
          final ride = _mapRide(j, _resolveType(j['vehicle_type'] ?? 'CAR'));
          activeRide = ride;
          return ride;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) throw _mapError(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<EarningsToday> fetchEarnings({bool force = false}) async {
    await _requireAuth();
    if (!force && _cachedEarnings != null) return _cachedEarnings!;
    try {
      final res = await _dio.get('$baseUrl/driver/earnings', options: _authOpts());
      final j = res.data['data'] as Map<String, dynamic>;
      _cachedEarnings = EarningsToday(
        gross: (j['gross'] as num?)?.toInt() ?? (j['today_bdt'] as num?)?.toInt() ?? 0,
        commission: (j['commission'] as num?)?.toInt() ?? 0,
        net: (j['net'] as num?)?.toInt() ?? (j['today_bdt'] as num?)?.toInt() ?? 0,
        trips: (j['trips'] as num?)?.toInt() ?? (j['rides'] as num?)?.toInt() ?? 0,
        debt: (j['debt'] as num?)?.toInt() ?? 0,
      );
      return _cachedEarnings!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Backwards-compatible accessor for callers using the mock signature.
  Future<EarningsToday> earningsRemote({Duration window = const Duration(hours: 8)}) {
    return fetchEarnings();
  }

  // ──────────────────────── helpers ────────────────────────
  Future<void> _requireAuth() async {
    if (access != null) return;
    if (refresh == null) {
      throw ApiException(code: ErrorCodes.unauthorized, message: 'Unauthorized', status: 401);
    }
    await refreshAccessToken();
  }

  Options _authOpts() => Options(headers: {'Authorization': 'Bearer $access'});

  String _phoneFromE164(String e164) {
    var d = e164.startsWith('+880') ? e164.substring(4) : e164;
    if (d.startsWith('0')) d = d.substring(1);
    return '0$d';
  }

  UserProfile _mapProfile(Map<String, dynamic> user) {
    final phone = user['phone'] as String?;
    return UserProfile(
      id: user['id'].toString(),
      phone: phone != null ? BdPhone.display(phone) : (sessionUser?.phone ?? ''),
      name: user['name'] as String?,
      email: user['email'] as String?,
      role: sessionUser?.role ?? AppRole.passenger,
      onboarding: sessionUser?.onboarding ?? DriverOnboardingStatus.approved,
      locationPrimed: user['is_profile_complete'] == true,
    );
  }

  VehicleType _mapVehicleType(Map<String, dynamic> j) {
    return VehicleType(
      id: (j['id'] ?? j['code']).toString(),
      code: j['code'] as String,
      nameBn: j['name_bn'] as String? ?? j['name'] as String? ?? j['code'] as String,
      nameEn: j['name_en'] as String? ?? j['name'] as String? ?? j['code'] as String,
      etaMin: (j['eta_min'] as num?)?.toInt() ?? 5,
      estimateBdt: (j['estimate_bdt'] as num?)?.toInt() ?? 0,
      base: (j['base_fare'] as num?)?.toInt() ?? (j['base'] as num?)?.toInt() ?? 30,
      perKm: (j['per_km'] as num?)?.toInt() ?? 15,
      perMin: (j['per_min'] as num?)?.toInt() ?? 2,
      minFare: (j['min_fare'] as num?)?.toInt() ?? 50,
      isActive: j['is_active'] as bool? ?? true,
    );
  }

  Ride _mapRide(Map<String, dynamic> j, VehicleType type) {
    final status = _mapRideStatus(j['status'] as String);
    final driverJson = j['driver'] as Map<String, dynamic>?;
    final total = (j['fare_bdt'] as num?)?.toInt() ??
        (j['estimated_fare'] as num?)?.toInt() ??
        type.estimateBdt;
    return Ride(
      id: j['id'].toString(),
      status: status,
      pickup: LatLng(
        (j['pickup_lat'] as num).toDouble(),
        (j['pickup_lng'] as num).toDouble(),
      ),
      pickupLabel: j['pickup_address'] as String? ?? '',
      drop: LatLng(
        (j['drop_lat'] as num).toDouble(),
        (j['drop_lng'] as num).toDouble(),
      ),
      dropLabel: j['drop_address'] as String? ?? '',
      vehicleType: type,
      paymentMethod: (j['payment_method'] as String? ?? 'CASH').toUpperCase(),
      pin: j['pin'] as String?,
      driverPoint: driverJson != null &&
              driverJson['lat'] != null &&
              driverJson['lng'] != null
          ? LatLng(
              (driverJson['lat'] as num).toDouble(),
              (driverJson['lng'] as num).toDouble(),
            )
          : null,
      fare: FareBreakdown(
        base: type.base,
        distance: total ~/ 3,
        time: total ~/ 5,
        minFare: type.minFare,
        total: total,
      ),
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      shareUrl: j['share_url'] as String? ?? activeRide?.shareUrl,
      driver: driverJson == null
          ? null
          : DriverCard(
              name: driverJson['name'] as String? ?? 'Driver',
              rating: (driverJson['rating'] as num?)?.toDouble() ?? 5.0,
              tripCount: (driverJson['trip_count'] as num?)?.toInt() ?? 0,
              vehicleModel: driverJson['vehicle'] as String? ?? '',
              color: driverJson['color'] as String? ?? '',
              plate: driverJson['plate'] as String? ?? '',
              etaMin: (driverJson['eta_min'] as num?)?.toInt() ?? 4,
              distanceKm: (driverJson['distance_km'] as num?)?.toDouble() ?? 0,
              isVerified: driverJson['is_verified'] as bool? ?? false,
              phone: driverJson['phone'] as String?,
            ),
    );
  }

  VehicleType _resolveType(dynamic raw) {
    String? slug;
    if (raw is String) {
      slug = raw;
    } else if (raw is Map) {
      slug = raw['slug'] as String?;
    }
    if (slug != null) {
      for (final t in _cachedTypes) {
        if (t.code == slug) return t;
      }
      if (slug == 'BIKE') return MockBackend.bike;
      if (slug == 'CAR') return MockBackend.car;
    }
    return _cachedTypes.isNotEmpty ? _cachedTypes.first : MockBackend.car;
  }

  /// Resolve a vehicle-type slug → numeric id for endpoints that expect an id.
  int? _vehicleTypeId(String slug) {
    for (final t in _cachedTypes) {
      if (t.code == slug) return int.tryParse(t.id);
    }
    return null;
  }

  RideStatus _mapRideStatus(String? raw) {
    switch (raw) {
      case 'searching':
      case 'pending':
      case 'requested':
        return RideStatus.requested;
      case 'assigned':
      case 'driver_assigned':
      case 'accepted':
      case 'driver_arriving':
        return RideStatus.accepted;
      case 'driver_arrived':
      case 'arrived':
        return RideStatus.driverArrived;
      case 'in_progress':
      case 'started':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      case 'no_show':
      case 'noShow':
        return RideStatus.noShow;
      case 'no_driver_available':
      case 'noDriverAvailable':
        return RideStatus.noDriverAvailable;
      default:
        return RideStatus.requested;
    }
  }
}

/// Adds Bearer token + handles 401 by refreshing once.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ApiBackend._peekAccess();
    if (token != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await ApiBackend._refreshGlobal();
        final retry = err.requestOptions;
        final token = ApiBackend._peekAccess();
        if (token != null) retry.headers['Authorization'] = 'Bearer $token';
        final dio = Dio(BaseOptions(baseUrl: retry.baseUrl));
        final cloned = await dio.fetch(retry);
        return handler.resolve(cloned);
      } catch (_) {
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}
