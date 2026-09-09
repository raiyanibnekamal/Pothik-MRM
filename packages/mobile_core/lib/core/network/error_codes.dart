abstract final class ErrorCodes {
  static const otpExpired = 'OTP_EXPIRED';
  static const otpInvalid = 'OTP_INVALID';
  static const rateLimit = 'RATE_LIMIT';
  static const smsDown = 'SMS_DOWN';
  static const noDrivers = 'NO_DRIVERS';
  static const duplicateNidPlate = 'DUPLICATE_NID_PLATE';
  static const guardianCap = 'GUARDIAN_CAP';
  static const alreadyPaid = 'ALREADY_PAID';
  static const outOfZone = 'OUT_OF_ZONE';
  static const sosNotAllowed = 'SOS_NOT_ALLOWED';
  static const debtCap = 'DEBT_CAP';
  static const graceOver = 'GRACE_OVER';
  static const badPhone = 'BAD_PHONE';
}

/// Must match packages/shared-types socket-events.ts
abstract final class SocketEvents {
  static const driverLocationUpdate = 'driver:location:update';
  static const driverStatus = 'driver:status';
  static const driverAccept = 'driver:accept';
  static const driverDecline = 'driver:decline';
  static const driverArrived = 'driver:arrived';
  static const driverCash = 'driver:cash';
  static const driverComplete = 'driver:complete';
  static const serverRideDispatched = 'server:ride:dispatched';
  static const serverRideCancelled = 'server:ride:cancelled';
  static const serverRideTimeout = 'server:ride:timeout';
  static const passengerCancel = 'passenger:cancel';
  static const serverRideAccepted = 'server:ride:accepted';
  static const serverDriverLocation = 'server:driver:location';
  static const serverRideArrived = 'server:ride:arrived';
  static const serverRideStarted = 'server:ride:started';
  static const serverRideCompleted = 'server:ride:completed';
  static const serverDriverCancel = 'server:driver:cancel';
  static const adminDashboard = 'admin.dashboard';
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
