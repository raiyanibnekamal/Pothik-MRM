/// Must match packages/shared-constants and apps/api/app/Constants/ErrorCodes.php
abstract final class ErrorCodes {
  static const invalidPhone = 'INVALID_PHONE';
  static const otpExpired = 'OTP_EXPIRED';
  static const otpInvalid = 'OTP_INVALID';
  static const otpRateLimit = 'OTP_RATE_LIMIT';
  static const otpMaxAttempts = 'OTP_MAX_ATTEMPTS';
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const validationError = 'VALIDATION_ERROR';
  static const duplicateNid = 'DUPLICATE_NID';
  static const duplicatePlate = 'DUPLICATE_PLATE';
  static const noDrivers = 'NO_DRIVERS';
  static const outOfZone = 'OUT_OF_ZONE';
  static const invalidTransition = 'INVALID_TRANSITION';
  static const pinMismatch = 'PIN_MISMATCH';
  static const alreadyPaid = 'ALREADY_PAID';
  static const sosNotAllowed = 'SOS_NOT_ALLOWED';
  static const guardianCap = 'GUARDIAN_CAP';
  static const duplicateGuardian = 'DUPLICATE_GUARDIAN';
  static const debtCap = 'DEBT_CAP';
  static const graceOver = 'GRACE_OVER';
  static const smsFailed = 'SMS_FAILED';
  static const alreadyRated = 'ALREADY_RATED';
  static const blocked = 'BLOCKED';

  // Legacy aliases used in UI copy paths
  static const badPhone = invalidPhone;
  static const rateLimit = otpRateLimit;
  static const smsDown = smsFailed;
  static const duplicateNidPlate = duplicateNid;
}

/// Must match packages/shared-types/src/socket-events.ts and SocketEvents.php
abstract final class SocketEvents {
  static const driverLocationUpdate = 'driver:location:update';
  static const driverStatusUpdate = 'driver:status:update';
  static const rideAccept = 'ride:accept';
  static const rideDecline = 'ride:decline';
  static const rideArrived = 'ride:arrived';
  static const rideCashConfirm = 'ride:cash:confirm';
  static const rideComplete = 'ride:complete';
  static const rideCancel = 'ride:cancel';
  static const serverRideDispatched = 'server:ride:dispatched';
  static const serverRideCancelled = 'server:ride:cancelled';
  static const serverRideTimeout = 'server:ride:timeout';
  static const serverRideAccepted = 'server:ride:accepted';
  static const serverDriverLocation = 'server:driver:location';
  static const serverDriverArrived = 'server:driver:arrived';
  static const serverRideStarted = 'server:ride:started';
  static const serverRideCompleted = 'server:ride:completed';
  static const serverDriverCancelled = 'server:driver:cancelled';
  static const adminSosAlert = 'admin:sos:alert';
  static const adminDashboard = 'admin:dashboard';
}

enum RideStatus {
  requested,
  accepted,
  driverArriving,
  driverArrived,
  inProgress,
  completed,
  cancelled,
  noShow,
  noDriverAvailable,
}

enum DriverOnboardingStatus {
  phoneVerified,
  personalDone,
  vehicleDone,
  docsPending,
  pendingReview,
  rejected,
  approved,
  grace,
}

class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.status = 400});
  final String code;
  final String message;
  final int status;

  @override
  String toString() => message;
}
