<?php

namespace Tests\Feature;

use App\Enums\RideStatus;
use App\Enums\UserRole;
use App\Models\Ride;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;

/**
 * S0 + S2 + S4 regressions consolidated:
 *  - S0.1  /auth/refresh is throttled (20/min)
 *  - S0.2  role cannot be escalated via OTP verify
 *  - S0.3  ride PIN is hidden from non-participants (admin may read it)
 *  - S4.3  only `cash` payment method is accepted
 */
class SecurityHardeningTest extends ApiTestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Relax the OTP and ride rate limits so back-to-back calls in this
        // class don't trip the production budgets (the budget itself is
        // covered by OtpRateLimitTest).
        config([
            'sms.rate_limit.phone_per_minute' => 100,
            'sms.rate_limit.ip_per_minute' => 100,
        ]);
    }

    private function seedRequestedRide(?int $driverId = null, string $payment = 'cash'): Ride
    {
        return Ride::create([
            'passenger_id' => $this->passenger->id,
            'driver_id' => $driverId,
            'vehicle_type_id' => $this->vehicleType->id,
            'status' => RideStatus::REQUESTED,
            'payment_method' => $payment,
            'pin' => '4821',
            'pickup_lat' => 23.7806,
            'pickup_lng' => 90.4074,
            'pickup_address' => 'P',
            'drop_lat' => 23.7925,
            'drop_lng' => 90.4078,
            'drop_address' => 'D',
        ]);
    }

    /** S0.1 — repeated refresh attempts are rate-limited. */
    public function test_auth_refresh_is_throttled(): void
    {
        // First request passes (no token, but throttle middleware runs).
        // We don't need a real token — the throttle counter is keyed on
        // requester IP and method/uri, so 25 hits exhaust the 20/min budget.
        for ($i = 0; $i < 25; $i++) {
            $this->postJson('/api/v1/auth/refresh', []);
        }

        $response = $this->postJson('/api/v1/auth/refresh', []);
        $response->assertStatus(429);
    }

    /** S0.2 — existing passenger's role is not changed by a `role` claim at verify. */
    public function test_role_cannot_be_escalated_at_otp_verify(): void
    {
        $phone = '+8801777777777';

        $this->postJson('/api/v1/auth/otp/request', ['phone' => $phone])
            ->assertStatus(200);
        $this->seedOtp($phone, '111111');

        // 1st verify creates a passenger.
        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => $phone,
            'code' => '111111',
        ])->assertStatus(200)->assertJsonPath('data.user.role', UserRole::PASSENGER);

        // 2nd verify attempts escalation to driver → should be ignored.
        $this->postJson('/api/v1/auth/otp/request', ['phone' => $phone])
            ->assertStatus(200);
        $this->seedOtp($phone, '222222');
        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => $phone,
            'code' => '222222',
            'role' => 'driver',
        ])->assertStatus(200)->assertJsonPath('data.user.role', UserRole::PASSENGER);
    }

    /** S0.3 — ride response hides PIN from any other authenticated user. */
    public function test_pin_is_hidden_from_other_users(): void
    {
        $ride = $this->seedRequestedRide();

        $response = $this->getJson(
            "/api/v1/rides/{$ride->id}",
            $this->authHeaders($this->passenger),
        );

        $response->assertStatus(200);
        // Passenger sees their own PIN.
        $response->assertJsonPath('data.pin', '4821');

        // Another passenger must not see it.
        $otherPassenger = \App\Models\User::create([
            'phone' => '+8801799999999',
            'role' => UserRole::PASSENGER,
            'language' => 'bn',
        ]);
        $this->getJson(
            "/api/v1/rides/{$ride->id}",
            $this->authHeaders($otherPassenger),
        )->assertStatus(403);
    }

    /** S4.3 — only `cash` payment method is accepted at ride creation. */
    public function test_only_cash_payment_method_is_accepted(): void
    {
        $body = [
            'vehicle_type_id' => $this->vehicleType->id,
            'pickup_lat' => 23.78,
            'pickup_lng' => 90.40,
            'pickup_address' => 'P',
            'drop_lat' => 23.79,
            'drop_lng' => 90.41,
            'drop_address' => 'D',
        ];

        // The rides route is also throttled (3/min by user) — bypass it
        // for this assertion-only test.
        $this->withoutMiddleware([\Illuminate\Routing\Middleware\ThrottleRequests::class]);

        foreach (['bkash', 'nagad', 'wallet', 'card'] as $bad) {
            $this->postJson(
                '/api/v1/rides',
                $body + ['payment_method' => $bad],
                $this->authHeaders($this->passenger),
            )->assertStatus(422);
        }

        $this->postJson(
            '/api/v1/rides',
            $body + ['payment_method' => 'cash'],
            $this->authHeaders($this->passenger),
        )->assertStatus(201);
    }
}
