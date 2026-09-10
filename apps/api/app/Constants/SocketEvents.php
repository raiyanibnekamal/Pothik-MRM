<?php

namespace App\Constants;

/**
 * Must stay in sync with packages/shared-types (frontend copies to Dart).
 */
class SocketEvents
{
    // Driver → server
    public const DRIVER_LOCATION_UPDATE = 'driver:location:update';
    public const DRIVER_STATUS_UPDATE = 'driver:status:update';
    public const RIDE_ACCEPT = 'ride:accept';
    public const RIDE_DECLINE = 'ride:decline';
    public const RIDE_ARRIVED = 'ride:arrived';
    public const RIDE_CASH_CONFIRM = 'ride:cash:confirm';
    public const RIDE_COMPLETE = 'ride:complete';

    // Passenger → server
    public const RIDE_CANCEL = 'ride:cancel';

    // Server → driver
    public const SERVER_RIDE_DISPATCHED = 'server:ride:dispatched';
    public const SERVER_RIDE_CANCELLED = 'server:ride:cancelled';
    public const SERVER_RIDE_TIMEOUT = 'server:ride:timeout';

    // Server → passenger
    public const SERVER_RIDE_ACCEPTED = 'server:ride:accepted';
    public const SERVER_DRIVER_LOCATION = 'server:driver:location';
    public const SERVER_DRIVER_ARRIVED = 'server:driver:arrived';
    public const SERVER_RIDE_STARTED = 'server:ride:started';
    public const SERVER_RIDE_COMPLETED = 'server:ride:completed';
    public const SERVER_DRIVER_CANCELLED = 'server:driver:cancelled';

    // Admin
    public const ADMIN_SOS_ALERT = 'admin:sos:alert';
    public const ADMIN_DASHBOARD = 'admin:dashboard';
}
