<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Constants\SocketEvents;
use App\Enums\RideStatus;
use App\Events\RideDispatched;
use App\Exceptions\ApiException;
use App\Jobs\DispatchTimeoutJob;
use App\Models\Ride;
use App\Models\RideDispatchAttempt;
use Illuminate\Support\Facades\DB;

class DispatchService
{
    private const OFFER_SECONDS = 15;
    private const MAX_DRIVERS = 5;
    private const MAX_SECONDS = 90;

    public function startDispatch(Ride $ride): void
    {
        if ($ride->status !== RideStatus::REQUESTED) {
            return;
        }

        DB::afterCommit(function () use ($ride) {
            $this->offerToNextDriver($ride->fresh());
        });
    }

    public function offerToNextDriver(Ride $ride): void
    {
        if (!in_array($ride->status, [RideStatus::REQUESTED], true)) {
            return;
        }

        $attemptCount = $ride->dispatchAttempts()->count();
        if ($attemptCount >= self::MAX_DRIVERS) {
            $this->markNoDriver($ride);

            return;
        }

        $firstOffer = $ride->dispatchAttempts()->oldest('offered_at')->first();
        if ($firstOffer && $firstOffer->offered_at->diffInSeconds(now()) >= self::MAX_SECONDS) {
            $this->markNoDriver($ride);

            return;
        }

        $excluded = $ride->dispatchAttempts()->pluck('driver_id')->all();
        $nearby = app(LocationService::class)->findNearbyDrivers(
            (float) $ride->pickup_lat,
            (float) $ride->pickup_lng,
            $ride->vehicle_type_id,
            5,
            $excluded
        );

        if (empty($nearby)) {
            $this->markNoDriver($ride);

            return;
        }

        $driver = $nearby[0];

        $attempt = RideDispatchAttempt::create([
            'ride_id' => $ride->id,
            'driver_id' => $driver['driver_id'],
            'result' => 'pending',
            'offered_at' => now(),
        ]);

        event(new RideDispatched($ride, $driver['driver_id'], $this->buildDispatchPayload($ride, $driver)));

        DispatchTimeoutJob::dispatch($attempt->id)->delay(now()->addSeconds(self::OFFER_SECONDS));
    }

    public function accept(Ride $ride, string $driverId): Ride
    {
        $attempt = RideDispatchAttempt::where('ride_id', $ride->id)
            ->where('driver_id', $driverId)
            ->where('result', 'pending')
            ->first();

        if (!$attempt) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'No pending offer', 404);
        }

        $attempt->update(['result' => 'accepted', 'responded_at' => now()]);

        $ride->update([
            'driver_id' => $driverId,
            'status' => RideStatus::ACCEPTED,
            'matched_at' => now(),
            'pin' => str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT),
        ]);

        return $ride->fresh(['driver.driverProfile', 'vehicleType', 'passenger']);
    }

    public function decline(Ride $ride, string $driverId): void
    {
        RideDispatchAttempt::where('ride_id', $ride->id)
            ->where('driver_id', $driverId)
            ->where('result', 'pending')
            ->update(['result' => 'declined', 'responded_at' => now()]);

        $this->offerToNextDriver($ride->fresh());
    }

    public function handleTimeout(int $attemptId): void
    {
        $attempt = RideDispatchAttempt::find($attemptId);
        if (!$attempt || $attempt->result !== 'pending') {
            return;
        }

        $attempt->update(['result' => 'timeout', 'responded_at' => now()]);

        $ride = $attempt->ride;
        if ($ride && $ride->status === RideStatus::REQUESTED) {
            $this->offerToNextDriver($ride);
        }
    }

    private function markNoDriver(Ride $ride): void
    {
        $ride->update(['status' => RideStatus::NO_DRIVER_AVAILABLE]);
    }

    private function buildDispatchPayload(Ride $ride, array $driver): array
    {
        return [
            'event' => SocketEvents::SERVER_RIDE_DISPATCHED,
            'ride_id' => $ride->id,
            'pickup' => [
                'lat' => (float) $ride->pickup_lat,
                'lng' => (float) $ride->pickup_lng,
                'area' => $this->maskAddress($ride->pickup_address),
            ],
            'drop' => [
                'area' => $this->maskAddress($ride->drop_address),
            ],
            'estimated_fare' => (float) $ride->estimated_fare,
            'payment_method' => $ride->payment_method,
            'distance_to_pickup_km' => round($driver['distance_km'], 2),
            'expires_in_seconds' => self::OFFER_SECONDS,
        ];
    }

    private function maskAddress(string $address): string
    {
        $parts = explode(',', $address);

        return trim(end($parts) ?: $address);
    }
}
