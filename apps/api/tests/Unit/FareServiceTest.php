<?php

namespace Tests\Unit;

use App\Models\VehicleType;
use App\Services\FareService;
use Tests\TestCase;

class FareServiceTest extends TestCase
{
    public function test_rounds_fare_to_nearest_five_taka(): void
    {
        $service = new FareService();

        $this->assertEquals(125.0, $service->roundToFive(123));
        $this->assertEquals(130.0, $service->roundToFive(128));
    }

    public function test_applies_min_fare_floor(): void
    {
        $service = new FareService();
        $type = new VehicleType([
            'base_fare' => 30,
            'per_km_rate' => 5,
            'per_min_rate' => 1,
            'min_fare' => 50,
        ]);

        $fare = $service->calculateFare($type, 0.5, 2);

        $this->assertEquals(50.0, $fare);
    }

    public function test_haversine_returns_positive_distance(): void
    {
        $service = new FareService();
        $km = $service->haversineKm(23.8103, 90.4125, 23.7808, 90.2792);

        $this->assertGreaterThan(10, $km);
        $this->assertLessThan(25, $km);
    }
}
