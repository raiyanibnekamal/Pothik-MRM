<?php

namespace Tests\Feature;

use App\Enums\RideStatus;
use App\Enums\UserRole;
use App\Models\Ride;
use App\Models\RideDispatchAttempt;
use Illuminate\Foundation\Testing\RefreshDatabase;

/**
 * Regression coverage for the ride lifecycle: store → accept → arriving →
 * arrived → pin verify → in_progress. Also covers the /driver/incoming poll
 * endpoint that Flutter's driver app hits while waiting for an offer.
 */
class RideLifecycleTest extends ApiTestCase
{
    use RefreshDatabase;

    private function createRide(): Ride
    {
        return Ride::create([
            'passenger_id' => $this->passenger->id,
            'driver_id' => null,
            'vehicle_type_id' => $this->vehicleType->id,
            'status' => RideStatus::REQUESTED,
            'payment_method' => 'cash',
            'pickup_lat' => 23.7806,
            'pickup_lng' => 90.4074,
            'pickup_address' => 'Dhanmondi 27',
            'drop_lat' => 23.7925,
            'drop_lng' => 90.4078,
            'drop_address' => 'Banani 11',
        ]);
    }

    public function test_passenger_can_create_ride(): void
    {
        $response = $this->postJson(
            '/api/v1/rides',
            [
                'vehicle_type_id' => $this->vehicleType->id,
                'pickup_lat' => 23.7806,
                'pickup_lng' => 90.4074,
                'pickup_address' => 'Dhanmondi 27',
                'drop_lat' => 23.7925,
                'drop_lng' => 90.4078,
                'drop_address' => 'Banani 11',
                'payment_method' => 'cash',
            ],
            $this->authHeaders($this->passenger),
        );

        $response->assertStatus(201);
        // formatRide nests pickup/drop under pickup.* and drop.*
        $response->assertJsonStructure([
            'data' => [
                'id',
                'status',
                'vehicle_type',
                'pickup' => ['lat', 'lng', 'address'],
                'drop' => ['lat', 'lng', 'address'],
            ],
        ]);
        $this->assertDatabaseCount('rides', 1);
    }

    public function test_routes_store_returns_vehicle_type_as_object(): void
    {
        $response = $this->postJson(
            '/api/v1/rides',
            [
                'vehicle_type_id' => $this->vehicleType->id,
                'pickup_lat' => 23.7806,
                'pickup_lng' => 90.4074,
                'pickup_address' => 'Dhanmondi 27',
                'drop_lat' => 23.7925,
                'drop_lng' => 90.4078,
                'drop_address' => 'Banani 11',
            ],
            $this->authHeaders($this->passenger),
        );

        $response->assertStatus(201);
        // Flutter's _resolveType must accept this nested shape — confirm the
        // contract that the previous broken version could not parse.
        $response->assertJsonPath('data.vehicle_type.slug', 'car');
        $response->assertJsonPath('data.vehicle_type.name_en', 'Car');
    }

    public function test_driver_can_accept_and_arriving(): void
    {
        $ride = $this->createRide();

        // DispatchService::accept only succeeds when a pending dispatch attempt
        // exists for this driver — seed one to bypass the geo lookup step.
        RideDispatchAttempt::create([
            'ride_id' => $ride->id,
            'driver_id' => $this->driver->id,
            'result' => 'pending',
            'offered_at' => now(),
        ]);

        $accept = $this->postJson(
            "/api/v1/rides/{$ride->id}/accept",
            [],
            $this->authHeaders($this->driver),
        );
        $accept->assertOk();
        $accept->assertJsonPath('data.status', RideStatus::ACCEPTED);

        $arriving = $this->postJson(
            "/api/v1/rides/{$ride->id}/arriving",
            [],
            $this->authHeaders($this->driver),
        );
        $arriving->assertOk();
        $arriving->assertJsonPath('data.status', RideStatus::DRIVER_ARRIVING);
    }

    public function test_passenger_cannot_accept_ride(): void
    {
        $ride = $this->createRide();

        $response = $this->postJson(
            "/api/v1/rides/{$ride->id}/accept",
            [],
            $this->authHeaders($this->passenger),
        );

        $response->assertStatus(403);
    }

    public function test_incoming_endpoint_returns_pending_offer(): void
    {
        $ride = $this->createRide();
        RideDispatchAttempt::create([
            'ride_id' => $ride->id,
            'driver_id' => $this->driver->id,
            'result' => 'pending',
            'offered_at' => now(),
        ]);

        $response = $this->getJson(
            '/api/v1/driver/incoming',
            $this->authHeaders($this->driver),
        );

        $response->assertOk();
        $response->assertJsonPath('data.ride.id', $ride->id);
    }

    public function test_incoming_endpoint_returns_null_when_no_offer(): void
    {
        $response = $this->getJson(
            '/api/v1/driver/incoming',
            $this->authHeaders($this->driver),
        );

        $response->assertOk();
        $response->assertJsonPath('data.ride', null);
    }

    public function test_cash_confirm_endpoint_accepts_amount_collected_field(): void
    {
        $ride = $this->createRide();
        // PaymentService requires the ride to be in_progress and locked_fare
        // to match the amount being confirmed.
        $ride->update([
            'driver_id' => $this->driver->id,
            'status' => RideStatus::IN_PROGRESS,
            'locked_fare' => 250.00,
        ]);

        $response = $this->postJson(
            "/api/v1/rides/{$ride->id}/cash-confirm",
            [
                'amount_collected' => 250.00,
            ],
            $this->authHeaders($this->driver),
        );

        $response->assertOk();
        $response->assertJsonStructure([
            'data' => ['transaction_id', 'already_processed', 'ride'],
        ]);
    }

    public function test_rate_endpoint_accepts_score_field(): void
    {
        $ride = $this->createRide();
        $ride->update([
            'driver_id' => $this->driver->id,
            'status' => RideStatus::COMPLETED,
        ]);

        $response = $this->postJson(
            "/api/v1/rides/{$ride->id}/rate",
            [
                'score' => 5,
                'comment' => 'Smooth ride',
            ],
            $this->authHeaders($this->passenger),
        );

        $response->assertOk();
        $this->assertDatabaseHas('ratings', [
            'ride_id' => $ride->id,
            'rater_id' => $this->passenger->id,
            'score' => 5,
        ]);
    }
}
