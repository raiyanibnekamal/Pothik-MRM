<?php

namespace Tests\Feature;

use App\Constants\ErrorCodes;
use App\Models\DriverProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;

/**
 * Regression coverage for the driver onboarding endpoints.
 *
 * Specifically guards the NID `regex:` rule that previously truncated at the
 * first pipe (`/^(\d{10}|\d{13}|\d{17})$/`) and returned a 500 HTML page when
 * Laravel handed the broken pattern to preg_match().
 */
class DriverOnboardingTest extends ApiTestCase
{
    use RefreshDatabase;

    public function test_save_personal_accepts_10_digit_nid(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => '1234567890']),
            $this->authHeaders($this->driver),
        );

        $response->assertOk();
        $this->assertDatabaseHas('driver_profiles', [
            'user_id' => $this->driver->id,
            'nid' => '1234567890',
        ]);
    }

    public function test_save_personal_accepts_13_digit_nid(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => '1234567890123']),
            $this->authHeaders($this->driver),
        );

        $response->assertOk();
    }

    public function test_save_personal_accepts_17_digit_nid(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => '12345678901234567']),
            $this->authHeaders($this->driver),
        );

        $response->assertOk();
    }

    public function test_save_personal_rejects_invalid_nid_length(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => '12345']),
            $this->authHeaders($this->driver),
        );

        $response->assertStatus(422);
        // API wraps ValidationException as error.errors.<field>
        $response->assertJsonPath('error.code', ErrorCodes::VALIDATION_ERROR);
        $this->assertArrayHasKey('nid', $response->json('error.errors'));
    }

    public function test_save_personal_rejects_alphabetic_nid(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => 'abcdefghij']),
            $this->authHeaders($this->driver),
        );

        $response->assertStatus(422);
        $response->assertJsonPath('error.code', ErrorCodes::VALIDATION_ERROR);
        $this->assertArrayHasKey('nid', $response->json('error.errors'));
    }

    public function test_save_personal_requires_18_plus_age(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['date_of_birth' => '2010-01-01']),
            $this->authHeaders($this->driver),
        );

        $response->assertStatus(422);
        $response->assertJsonPath('error.code', ErrorCodes::VALIDATION_ERROR);
        $this->assertArrayHasKey('date_of_birth', $response->json('error.errors'));
    }

    public function test_save_personal_returns_json_401_for_unauthenticated_driver(): void
    {
        $response = $this->postJson('/api/v1/driver/personal', $this->validPersonalPayload());

        // Plain 401 JSON — not an HTML login redirect — because the API
        // middleware must not leak the web auth flow.
        $response->assertStatus(401);
        $this->assertIsArray($response->json());
    }

    public function test_save_personal_blocks_duplicate_nid_for_other_driver(): void
    {
        $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => '99999999999999999']),
            $this->authHeaders($this->driver),
        )->assertOk();

        $otherDriver = \App\Models\User::create([
            'phone' => '+8801733333333',
            'role' => \App\Enums\UserRole::DRIVER,
            'language' => 'bn',
        ]);

        $response = $this->postJson(
            '/api/v1/driver/personal',
            $this->validPersonalPayload(['nid' => '99999999999999999']),
            $this->authHeaders($otherDriver),
        );

        $response->assertStatus(409);
        $response->assertJsonPath('error.code', ErrorCodes::DUPLICATE_NID);
    }

    public function test_save_vehicle_requires_numeric_vehicle_type_id(): void
    {
        $payload = [
            'vehicle_type_id' => $this->vehicleType->id,
            'vehicle_make' => 'Toyota',
            'vehicle_model' => 'Corolla',
            'vehicle_year' => 2020,
            'vehicle_color' => 'White',
            'plate_no' => 'DM-TA-1234',
        ];

        $response = $this->postJson('/api/v1/driver/vehicle', $payload, $this->authHeaders($this->driver));

        $response->assertOk();
        $this->assertDatabaseHas('driver_profiles', [
            'user_id' => $this->driver->id,
            'plate_no' => 'DM-TA-1234',
            'vehicle_make' => 'Toyota',
        ]);
    }

    public function test_save_vehicle_rejects_missing_vehicle_type_id(): void
    {
        $response = $this->postJson(
            '/api/v1/driver/vehicle',
            [
                'vehicle_make' => 'Toyota',
                'vehicle_model' => 'Corolla',
                'vehicle_year' => 2020,
                'vehicle_color' => 'White',
                'plate_no' => 'DM-TA-9999',
            ],
            $this->authHeaders($this->driver),
        );

        $response->assertStatus(422);
        $response->assertJsonPath('error.code', ErrorCodes::VALIDATION_ERROR);
        $this->assertArrayHasKey('vehicle_type_id', $response->json('error.errors'));
    }

    private function validPersonalPayload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Karim Driver',
            'nid' => '1234567890',
            'date_of_birth' => '1995-01-15',
            'address' => 'House 12, Road 7, Dhanmondi, Dhaka',
        ], $overrides);
    }
}
