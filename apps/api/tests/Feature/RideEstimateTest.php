<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;

/**
 * Regression coverage for the /rides/estimate endpoint.
 *
 * Before the fix Flutter's ApiBackend called estimate via POST but the route
 * was registered as GET-only — every estimate request returned 405. These
 * tests pin the Route::match(['get', 'post']) behaviour so it cannot regress.
 */
class RideEstimateTest extends ApiTestCase
{
    use RefreshDatabase;

    private function estimatePayload(): array
    {
        return [
            'vehicle_type_id' => $this->vehicleType->id,
            'pickup_lat' => 23.7806,
            'pickup_lng' => 90.4074,
            'drop_lat' => 23.7925,
            'drop_lng' => 90.4078,
        ];
    }

    public function test_estimate_endpoint_accepts_post(): void
    {
        $response = $this->postJson(
            '/api/v1/rides/estimate',
            $this->estimatePayload(),
            $this->authHeaders($this->passenger),
        );

        $response->assertOk();
        $response->assertJsonStructure([
            'data' => [
                'fare',
                'distance_km',
                'duration_min',
            ],
        ]);
    }

    public function test_estimate_endpoint_accepts_get(): void
    {
        $response = $this->getJson(
            '/api/v1/rides/estimate?' . http_build_query($this->estimatePayload()),
            $this->authHeaders($this->passenger),
        );

        $response->assertOk();
    }

    public function test_estimate_requires_authentication(): void
    {
        // No auth headers → expect 401 JSON, not a 405 redirect or HTML page.
        $response = $this->postJson('/api/v1/rides/estimate', $this->estimatePayload());

        $response->assertStatus(401);
        $this->assertIsArray($response->json());
    }

    public function test_estimate_rejects_invalid_vehicle_type_id(): void
    {
        $response = $this->postJson(
            '/api/v1/rides/estimate',
            array_merge($this->estimatePayload(), ['vehicle_type_id' => 99999]),
            $this->authHeaders($this->passenger),
        );

        $response->assertStatus(422);
        $response->assertJsonPath('error.code', \App\Constants\ErrorCodes::VALIDATION_ERROR);
        $this->assertArrayHasKey('vehicle_type_id', $response->json('error.errors'));
    }

    public function test_batch_estimate_accepts_post(): void
    {
        $response = $this->postJson(
            '/api/v1/rides/estimate/batch',
            [
                'pickup_lat' => 23.7806,
                'pickup_lng' => 90.4074,
                'drop_lat' => 23.7925,
                'drop_lng' => 90.4078,
            ],
            $this->authHeaders($this->passenger),
        );

        $response->assertOk();
        $response->assertJsonStructure([
            'data' => [
                '*' => ['vehicle_type_id', 'slug', 'fare', 'eta_min'],
            ],
        ]);
    }
}
