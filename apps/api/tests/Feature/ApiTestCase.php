<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\OtpCode;
use App\Models\User;
use App\Models\VehicleType;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Shared base for HTTP feature tests.
 *
 * Provides authenticated JWT requests for a passenger or driver and a known
 * active VehicleType so individual test classes stay focused on their
 * regression target.
 */
abstract class ApiTestCase extends TestCase
{
    protected User $passenger;
    protected User $driver;
    protected VehicleType $vehicleType;

    protected function setUp(): void
    {
        parent::setUp();

        $this->vehicleType = VehicleType::create([
            'slug' => 'car',
            'name_en' => 'Car',
            'name_bn' => 'কার',
            'seats' => 4,
            'base_fare' => 50.00,
            'per_km_rate' => 18.00,
            'per_min_rate' => 2.00,
            'min_fare' => 60.00,
            'is_active' => true,
        ]);

        $this->passenger = User::create([
            'phone' => '+8801711111111',
            'role' => UserRole::PASSENGER,
            'language' => 'bn',
        ]);

        $this->driver = User::create([
            'phone' => '+8801722222222',
            'role' => UserRole::DRIVER,
            'language' => 'bn',
        ]);
    }

    /**
     * Authenticate a user for the next request and return their bearer token.
     * Bypasses the OTP flow entirely so tests stay focused on the endpoint
     * under test.
     */
    protected function authHeaders(User $user): array
    {
        $token = auth('api')->login($user);

        return [
            'Authorization' => 'Bearer ' . $token,
            'Accept' => 'application/json',
        ];
    }

    /**
     * Returns the latest OTP code for a given phone. Used to drive the OTP
     * endpoint without scraping logs.
     */
    protected function latestOtpFor(string $phone): string
    {
        // OTP codes are hashed, so we deliberately request one through the
        // API and capture the most recent record. To discover the code we
        // overwrite its hash with a known value via the OtpCode model in
        // tests that need it (see AuthOtpTest).
        $record = OtpCode::where('phone', $phone)->latest('id')->first();
        $this->assertNotNull($record, "No OTP requested for {$phone}");

        // The hash was created with Hash::make during requestOtp — we can't
        // reverse it, so test code that needs the code must re-request and
        // then read it back via the dedicated helper below.
        return '';
    }

    /**
     * Issues a known code for a phone by writing directly into the OTP table.
     * This mirrors what OtpService::requestOtp does but with a deterministic
     * value the test owns.
     */
    protected function seedOtp(string $phone, string $code = '123456'): void
    {
        OtpCode::where('phone', $phone)->delete();
        OtpCode::create([
            'phone' => $phone,
            'code_hash' => Hash::make($code),
            'purpose' => 'login',
            'expires_at' => now()->addMinutes(5),
        ]);
    }
}
