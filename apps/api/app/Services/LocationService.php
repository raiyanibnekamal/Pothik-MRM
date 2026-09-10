<?php

namespace App\Services;

use App\Constants\ErrorCodes;
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

        return [
            'lat' => $lat,
            'lng' => $lng,
            'speed_jump_flag' => $speedJump,
        ];
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
