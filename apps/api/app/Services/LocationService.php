<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Events\DriverLocationUpdated;
use App\Exceptions\ApiException;
use App\Models\DriverLocation;
use App\Models\DriverProfile;
use App\Models\PlatformConfig;
use App\Models\Ride;
use Illuminate\Support\Facades\Redis;

class LocationService
{
    private const REDIS_TTL = 60;
    private const MAX_SPEED_KMH = 150;

    public function validateCoordinates(float $lat, float $lng): void
    {
        if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
            throw new ApiException(ErrorCodes::VALIDATION_ERROR, 'Invalid coordinates', 422);
        }
    }

    public function updateDriverLocation(
        string $driverId,
        float $lat,
        float $lng,
        ?float $speedKmh = null,
        ?string $rideId = null
    ): array {
        $this->validateCoordinates($lat, $lng);

        $speedJump = $speedKmh !== null && $speedKmh > self::MAX_SPEED_KMH;

        $key = "driver:{$driverId}:location";
        Redis::setex($key, self::REDIS_TTL, json_encode([
            'lat' => $lat,
            'lng' => $lng,
            'speed_kmh' => $speedKmh,
            'updated_at' => now()->toIso8601String(),
        ]));

        DriverProfile::where('user_id', $driverId)->update([
            'current_lat' => $lat,
            'current_lng' => $lng,
            'location_updated_at' => now(),
        ]);

        $shouldPersist = $this->shouldPersistLocation($driverId, $rideId);

        if ($shouldPersist) {
            DriverLocation::create([
                'driver_id' => $driverId,
                'ride_id' => $rideId,
                'lat' => $lat,
                'lng' => $lng,
                'speed_kmh' => $speedKmh,
                'speed_jump_flag' => $speedJump,
            ]);
        }

        // Best-effort broadcast to the matched passenger. Failures here
        // never fail the HTTP call — Redis is the source of truth for the
        // admin live-map, so the websocket path is purely a UX enhancement.
        $this->broadcastDriverLocation(
            driverId: $driverId,
            rideId: (string) ($rideId ?? ''),
            lat: $lat,
            lng: $lng,
            speedKmh: $speedKmh,
            bearingDeg: null,
        );

        return [
            'lat' => $lat,
            'lng' => $lng,
            'speed_jump_flag' => $speedJump,
        ];
    }

    /**
     * Push a driver location ping to the matched passenger over the private
     * broadcast channel. No-op if the driver isn't currently on a ride or the
     * ride has no assigned passenger (e.g. driver offline + pinging for
     * background location services). The `bearing` arg is optional; the
     * existing /driver/location route doesn't send it yet, so the mobile
     * client just sees null and the map marker stops rotating — that's
     * acceptable until Phase 1 adds bearing telemetry.
     */
    public function broadcastDriverLocation(
        string $driverId,
        string $rideId,
        float $lat,
        float $lng,
        ?float $speedKmh = null,
        ?float $bearingDeg = null
    ): void {
        $ride = Ride::find($rideId);

        if (!$ride || !$ride->passenger_id) {
            return;
        }

        // Only fan out during rides a passenger is actively tracking. Earlier
        // statuses (requested/accepted) are too noisy — the driver marker
        // belongs on the passenger's live-tracking screen, not on the home map.
        if (!in_array($ride->status, [
            \App\Enums\RideStatus::ACCEPTED,
            \App\Enums\RideStatus::DRIVER_ARRIVING,
            \App\Enums\RideStatus::DRIVER_ARRIVED,
            \App\Enums\RideStatus::IN_PROGRESS,
        ], true)) {
            return;
        }

        event(new DriverLocationUpdated(
            rideId: $rideId,
            passengerId: (string) $ride->passenger_id,
            driverId: $driverId,
            lat: $lat,
            lng: $lng,
            speedKmh: $speedKmh,
            bearingDeg: $bearingDeg,
            updatedAt: now()->toIso8601String(),
        ));
    }

    public function getDriverLocation(string $driverId): ?array
    {
        $data = Redis::get("driver:{$driverId}:location");

        return $data ? json_decode($data, true) : null;
    }

    public function findNearbyDrivers(
        float $lat,
        float $lng,
        int $vehicleTypeId,
        float $radiusKm = 5,
        array $excludeDriverIds = []
    ): array {
        $drivers = DriverProfile::with('user')
            ->where('is_online', true)
            ->where('is_on_break', false)
            ->where('vehicle_type_id', $vehicleTypeId)
            ->whereNotNull('current_lat')
            ->whereNotNull('current_lng')
            ->get();

        $nearby = [];

        foreach ($drivers as $profile) {
            if (in_array($profile->user_id, $excludeDriverIds, true)) {
                continue;
            }

            if (!$profile->canGoOnline()) {
                continue;
            }

            if ($this->hasUnpaidDebtCap($profile->user_id)) {
                continue;
            }

            if ($this->isDriverBusy($profile->user_id)) {
                continue;
            }

            $distance = app(FareService::class)->haversineKm(
                $lat, $lng,
                (float) $profile->current_lat,
                (float) $profile->current_lng
            );

            if ($distance <= $radiusKm) {
                $nearby[] = [
                    'driver_id' => $profile->user_id,
                    'distance_km' => $distance,
                    'rating' => $profile->user->rating_avg,
                    'acceptance_rate' => $profile->acceptance_rate,
                    'eta_min' => max(1, (int) ceil(($distance / 25) * 60)),
                ];
            }
        }

        usort($nearby, fn ($a, $b) => $this->rankScore($b) <=> $this->rankScore($a));

        return $nearby;
    }

    private function rankScore(array $driver): float
    {
        $etaScore = max(0, 100 - ($driver['eta_min'] * 5)) * 0.5;
        $ratingScore = ($driver['rating'] / 5) * 100 * 0.3;
        $arScore = ($driver['acceptance_rate'] / 100) * 100 * 0.2;

        return $etaScore + $ratingScore + $arScore;
    }

    private function isDriverBusy(string $driverId): bool
    {
        return Ride::where('driver_id', $driverId)
            ->whereIn('status', ['accepted', 'driver_arriving', 'driver_arrived', 'in_progress'])
            ->exists();
    }

    private function hasUnpaidDebtCap(string $driverId): bool
    {
        $cap = (float) (PlatformConfig::get('debt_cap', ['amount' => 5000])['amount'] ?? 5000);
        $debt = \App\Models\DriverCommissionDebt::where('driver_id', $driverId)
            ->where('is_paid', false)
            ->sum('amount');

        return $debt >= $cap;
    }

    private function shouldPersistLocation(string $driverId, ?string $rideId): bool
    {
        if ($rideId) {
            $ride = Ride::find($rideId);
            if ($ride && $ride->sos_active) {
                return true;
            }
        }

        $lastKey = "driver:{$driverId}:last_persist";
        $last = Redis::get($lastKey);

        if (!$last || now()->diffInSeconds(\Carbon\Carbon::parse($last)) >= 30) {
            Redis::setex($lastKey, 120, now()->toIso8601String());

            return true;
        }

        return false;
    }
}
