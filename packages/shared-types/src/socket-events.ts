/**
 * Socket event names — must match app/Constants/SocketEvents.php (Laravel).
 * Frontend/Dart copies these string constants manually until codegen ships.
 */
export const SOCKET_EVENTS = {
  DRIVER_LOCATION_UPDATE: 'driver:location:update',
  DRIVER_STATUS_UPDATE: 'driver:status:update',
  RIDE_ACCEPT: 'ride:accept',
  RIDE_DECLINE: 'ride:decline',
  RIDE_ARRIVED: 'ride:arrived',
  RIDE_CASH_CONFIRM: 'ride:cash:confirm',
  RIDE_COMPLETE: 'ride:complete',
  RIDE_CANCEL: 'ride:cancel',
  SERVER_RIDE_DISPATCHED: 'server:ride:dispatched',
  SERVER_RIDE_CANCELLED: 'server:ride:cancelled',
  SERVER_RIDE_TIMEOUT: 'server:ride:timeout',
  SERVER_RIDE_ACCEPTED: 'server:ride:accepted',
  SERVER_DRIVER_LOCATION: 'server:driver:location',
  SERVER_DRIVER_ARRIVED: 'server:driver:arrived',
  SERVER_RIDE_STARTED: 'server:ride:started',
  SERVER_RIDE_COMPLETED: 'server:ride:completed',
  SERVER_DRIVER_CANCELLED: 'server:driver:cancelled',
  ADMIN_SOS_ALERT: 'admin:sos:alert',
  ADMIN_DASHBOARD: 'admin:dashboard',
} as const;

export type SocketEventName = typeof SOCKET_EVENTS[keyof typeof SOCKET_EVENTS];
