<?php

namespace App\Services;

use App\Models\PlatformConfig;
use App\Models\VehicleType;

class FareService
{
    public function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return $earthRadius * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    public function estimate(
        VehicleType $vehicleType,
        float $pickupLat,
        float $pickupLng,
        float $dropLat,
        float $dropLng
    ): array {
        $distanceKm = $this->haversineKm($pickupLat, $pickupLng, $dropLat, $dropLng);
        $durationMin = max(1, (int) ceil(($distanceKm / 20) * 60));

        $fare = $this->calculateFare($vehicleType, $distanceKm, $durationMin);

        return [
            'distance_km' => round($distanceKm, 2),
            'duration_min' => $durationMin,
            'fare' => $fare,
            'breakdown' => [
                'base' => (float) $vehicleType->base_fare,
                'distance' => round($distanceKm * $vehicleType->per_km_rate, 2),
                'time' => round($durationMin * $vehicleType->per_min_rate, 2),
                'min_fare' => (float) $vehicleType->min_fare,
            ],
        ];
    }

    public function calculateFare(VehicleType $vehicleType, float $distanceKm, int $durationMin, float $surge = 1.0): float
    {
        $raw = $vehicleType->base_fare
            + ($distanceKm * $vehicleType->per_km_rate)
            + ($durationMin * $vehicleType->per_min_rate);

        $withSurge = $raw * $surge;
        $withMin = max($withSurge, $vehicleType->min_fare);

        return $this->roundToFive($withMin);
    }

    public function lockFare(
        VehicleType $vehicleType,
        float $pickupLat,
        float $pickupLng,
        float $dropLat,
        float $dropLng
    ): array {
        $estimate = $this->estimate($vehicleType, $pickupLat, $pickupLng, $dropLat, $dropLng);

        $usedGoogle = false;
        $flagged = false;

        if (config('services.google.maps_api_key')) {
            try {
                $google = $this->fetchGoogleDistance($pickupLat, $pickupLng, $dropLat, $dropLng);
                if ($google) {
                    $estimate['distance_km'] = $google['distance_km'];
                    $estimate['duration_min'] = $google['duration_min'];
                    $estimate['fare'] = $this->calculateFare(
                        $vehicleType,
                        $google['distance_km'],
                        $google['duration_min']
                    );
                    $usedGoogle = true;
                }
            } catch (\Throwable) {
                $flagged = true;
            }
        }

        return [
            'locked_fare' => $estimate['fare'],
            'distance_km' => $estimate['distance_km'],
            'duration_min' => $estimate['duration_min'],
            'fare_locked_with_google' => $usedGoogle,
            'fare_flagged_for_ops' => $flagged,
        ];
    }

    public function roundToFive(float $amount): float
    {
        return round($amount / 5) * 5;
    }

    public function getCommissionRate(): float
    {
        $config = PlatformConfig::get('commission_rate', ['rate' => 20]);

        return (float) ($config['rate'] ?? 20);
    }

    private function fetchGoogleDistance(float $lat1, float $lng1, float $lat2, float $lng2): ?array
    {
        $key = config('services.google.maps_api_key');
        if (!$key) {
            return null;
        }

        $response = \Illuminate\Support\Facades\Http::timeout(10)->get(
            'https://maps.googleapis.com/maps/api/distancematrix/json',
            [
                'origins' => "{$lat1},{$lng1}",
                'destinations' => "{$lat2},{$lng2}",
                'key' => $key,
            ]
        );

        if (!$response->successful()) {
            return null;
        }

        $element = $response->json('rows.0.elements.0');
        if (($element['status'] ?? '') !== 'OK') {
            return null;
        }

        return [
            'distance_km' => ($element['distance']['value'] ?? 0) / 1000,
            'duration_min' => (int) ceil(($element['duration']['value'] ?? 0) / 60),
        ];
    }
}
