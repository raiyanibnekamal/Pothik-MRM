<?php

use App\Enums\UserRole;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Channels that begin with "private-" require authentication. The client
| requests a channel name from the mobile/admin app, the server hits
| POST /broadcasting/auth with the user's JWT, and the closure below decides
| whether the connection is allowed. A `false` return is a clean 403.
|
| Channel layout (matches apps/api/app/Constants/SocketEvents.php):
|   user.{id}        — generic private notifications for a single user
|   ride.{id}        — ride-scoped group: only the matched passenger + driver
|   passenger.{id}   — driver → passenger stream (live location, ride status)
|   driver.{id}      — server → driver stream (dispatch offers, cancellations)
|   admin.ops        — admin-only fan-out for the war-room dashboard
|   admin.sos        — admin-only fan-out for active SOS alerts (subset of ops)
|
| Channels are named here; the actual broadcast delivery is driven by
| ShouldBroadcast events. The Reverb/Pusher server only delivers channels
| that have at least one subscribed socket — orphaned channels cost nothing.
|
*/

Broadcast::channel('user.{id}', function ($user, $id) {
    return $user->id === $id;
});

Broadcast::channel('ride.{id}', function ($user, $id) {
    return \App\Models\Ride::where('id', $id)
        ->where(function ($q) use ($user) {
            $q->where('passenger_id', $user->id)->orWhere('driver_id', $user->id);
        })->exists();
});

// Server pushes driver location + ride state to the passenger on this channel.
// Only the passenger whose id matches can subscribe — drivers, admins, and
// other passengers are denied. The corresponding event
// (App\Events\DriverLocationUpdated) always broadcasts on private-passenger.{id},
// so the channel authorisation guarantees the location stream cannot leak.
Broadcast::channel('passenger.{id}', function ($user, $id) {
    return $user->id === $id;
});

// Server pushes dispatch offers, ride cancellations, and timeouts to the driver
// on this channel. Same rule: only the matching driver can subscribe.
Broadcast::channel('driver.{id}', function ($user, $id) {
    return $user->id === $id;
});

// Admin war-room feed. Same authorization as admin.ops — both names are kept
// so we can split low-rate admin traffic (driver presence, ride stats) from
// high-priority SOS bursts without changing subscriber code later.
Broadcast::channel('admin.ops', function ($user) {
    return UserRole::isAdmin($user->role);
});

Broadcast::channel('admin.sos', function ($user) {
    return UserRole::isAdmin($user->role);
});

