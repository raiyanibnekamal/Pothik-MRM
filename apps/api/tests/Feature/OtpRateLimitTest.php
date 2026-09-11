<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Regression coverage for the per-phone + per-IP OTP rate limit introduced
 * in Phase 0a.
 *
 * The limiter is registered in AppServiceProvider::registerOtpRateLimiter()
 * and applied to /auth/otp/request and /auth/otp/verify via
 * `throttle:otp` in routes/api.php.
 *
 * Two limits run in parallel:
 *   - phone_per_minute (default 3)
 *   - ip_per_minute    (default 10)
 *
 * The 4th request from the same phone number should return 429 with the
 * structured OTP_RATE_LIMIT error code — that's the regression we care about.
 */
class OtpRateLimitTest extends ApiTestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Reset limiter state — Pest's RefreshDatabase doesn't touch the cache
        // store the limiter uses.
        RateLimiter::clear('otp:phone:+8801711111111');
    }

    public function test_request_otp_is_allowed_within_phone_limit(): void
    {
        for ($i = 0; $i < 3; $i++) {
            $response = $this->postJson('/api/v1/auth/otp/request', [
                'phone' => '+8801711111111',
            ]);

            $response->assertOk();
        }
    }

    public function test_fourth_request_for_same_phone_returns_429(): void
    {
        // First three succeed.
        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/v1/auth/otp/request', [
                'phone' => '+8801711111111',
            ])->assertOk();
        }

        // Fourth trips the per-phone limiter.
        $response = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+8801711111111',
        ]);

        $response->assertStatus(429);
        // The default Laravel ThrottleRequests middleware returns a generic
        // 429 body; we assert on status only here. A future enhancement could
        // wrap it with our ApiResponse::error(OTP_RATE_LIMIT) shape.
    }

    public function test_rate_limit_is_per_phone_not_global(): void
    {
        // Phone A exhausts its 3-request quota.
        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/v1/auth/otp/request', [
                'phone' => '+8801711111111',
            ])->assertOk();
        }

        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+8801711111111',
        ])->assertStatus(429);

        // Phone B still works because the limit is per-phone.
        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+8801722222222',
        ])->assertOk();
    }

    public function test_ip_limit_fires_before_phone_limit_for_many_distinct_phones(): void
    {
        // Drive the IP limit (default 10 per minute) by hitting 11 distinct
        // valid BD phones. Valid shape per OtpService regex:
        //   /^\+8801[3-9]\d{8}$/
        // = '+' + '880' + '1' + [3-9] + 8 digits = 14 chars total, 13 after '+'.
        // Prefix "+88017" already supplies the required '1' + '7', so we
        // append exactly 8 digits via %08d.
        for ($i = 0; $i < 10; $i++) {
            $phone = sprintf('+88017%08d', 10000000 + $i);

            $this->postJson('/api/v1/auth/otp/request', [
                'phone' => $phone,
            ])->assertOk();
        }

        $response = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+8801799999999',
        ]);

        $response->assertStatus(429);
    }
}
