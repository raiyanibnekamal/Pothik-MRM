/// Mirror of apps/api/app/Constants/SocketEvents.php. Keep in sync when
/// the server gains a new event; the build will break if either side
/// drifts, which is intentional.
class SocketEvents {
  SocketEvents._();

  // Driver → server (driver app only; listed here for parity)
  static const String driverLocationUpdate = 'driver:location:update';
  static const String driverStatusUpdate = 'driver:status:update';
  static const String rideAccept = 'ride:accept';
  static const String rideDecline = 'ride:decline';
  static const String rideArrived = 'ride:arrived';
  static const String rideCashConfirm = 'ride:cash:confirm';
  static const String rideComplete = 'ride:complete';

  // Passenger → server (passenger app only; listed here for parity)
  static const String rideCancel = 'ride:cancel';

  // Server → driver (driver app only)
  static const String serverRideDispatched = 'server:ride:dispatched';
  static const String serverRideCancelled = 'server:ride:cancelled';
  static const String serverRideTimeout = 'server:ride:timeout';

  // Server → passenger (passenger app)
  static const String serverRideAccepted = 'server:ride:accepted';
  static const String serverDriverLocation = 'server:driver:location';
  static const String serverDriverArrived = 'server:driver:arrived';
  static const String serverRideStarted = 'server:ride:started';
  static const String serverRideCompleted = 'server:ride:completed';
  static const String serverDriverCancelled = 'server:driver:cancelled';

  // Admin
  static const String adminSosAlert = 'admin:sos:alert';
  static const String adminDashboard = 'admin:dashboard';
}
