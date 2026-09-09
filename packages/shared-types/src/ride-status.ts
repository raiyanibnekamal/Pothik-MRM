/** Must match apps/api/app/Enums/RideStatus.php */
export const RIDE_STATUS = {
  REQUESTED: 'requested',
  ACCEPTED: 'accepted',
  DRIVER_ARRIVING: 'driver_arriving',
  DRIVER_ARRIVED: 'driver_arrived',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled',
  NO_SHOW: 'no_show',
  NO_DRIVER_AVAILABLE: 'no_driver_available',
} as const

export type RideStatus = typeof RIDE_STATUS[keyof typeof RIDE_STATUS]
