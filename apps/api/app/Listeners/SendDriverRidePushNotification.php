<?php

namespace App\Listeners;

use App\Events\RideDispatched;
use App\Services\Fcm\FcmService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

/**
 * Hooked onto RideDispatched (S2.4) so a driver whose socket is offline
 * still sees an OS-level push on their phone.
 *
 * In local / staging where FCM_DEFAULT_PROVIDER=null, the underlying
 * NullFcmService logs the intent and returns true so this listener is
 * safe to register today and starts delivering once the Firebase project
 * is wired (S4.2).
 *
 * Implements ShouldQueue so dispatch never blocks the HTTP request that
 * fired RideDispatched; FCM is a best-effort wake-up channel.
 */
class SendDriverRidePushNotification implements ShouldQueue
{
    public function __construct(private FcmService $fcm) {}

    public function handle(RideDispatched $event): void
    {
        $ride = $event->ride;
        $title = 'নতুন রাইড';
        $body = sprintf(
            '৳%s · %s থেকে %s',
            $ride->estimated_fare ?? '—',
            $ride->pickup_address ?? 'pickup',
            $ride->drop_address ?? 'drop'
        );

        $ok = $this->fcm->sendToUser(
            $event->driverId,
            $title,
            $body,
            [
                'ride_id' => (string) $ride->id,
                'type' => 'ride_dispatched',
            ]
        );

        if (! $ok) {
            // Don't crash the dispatch path — the socket is the source
            // of truth, push is a fallback. Surfacing a log line gives
            // ops a way to alert on persistent FCM failures.
            Log::warning('fcm.driver_dispatch_failed', [
                'driver_id' => $event->driverId,
                'ride_id' => $ride->id,
            ]);
        }
    }
}
