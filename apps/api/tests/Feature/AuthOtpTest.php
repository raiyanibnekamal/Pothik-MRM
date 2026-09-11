<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

/**
 * Regression coverage for the OTP auth flow.
 *
 * Flutter's `verifyOtp` posts `{phone, code, role}` to /auth/otp/verify and
 * expects a `{access_token, refresh_token, user}` payload. The earlier 500
 * regression surfaced when Laravel's validation rule parser saw a pipe in a
 * regex — this test pins the happy path so the contract cannot drift.
 */
class AuthOtpTest extends ApiTestCase
{
    use RefreshDatabase;

    public function test_request_otp_accepts_valid_bd_phone(): void
    {
        $response = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+8801711111111',
        ]);

        $response->assertOk();
        $response->assertJsonPath('message', 'OTP sent');
    }

    public function test_request_otp_rejects_malformed_phone(): void
    {
        $response = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => 'not-a-phone',
        ]);

        // OtpService raises an ApiException for invalid phone — the contract
        // is "structured error JSON", not Laravel's default validator bag.
        $response->assertStatus(422);
        $response->assertJsonPath('error.code', \App\Constants\ErrorCodes::INVALID_PHONE);
    }

    public function test_verify_otp_issues_tokens_for_passenger(): void
    {
        $this->seedOtp('+8801711111111', '654321');

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+8801711111111',
            'code' => '654321',
            'role' => UserRole::PASSENGER,
        ]);

        $response->assertOk();
        $response->assertJsonStructure([
            'data' => [
                'access_token',
                'refresh_token',
                'user' => ['id', 'phone', 'role'],
            ],
        ]);
        $this->assertDatabaseHas('users', [
            'phone' => '+8801711111111',
            'role' => UserRole::PASSENGER,
        ]);
    }

    public function test_verify_otp_issues_tokens_for_driver(): void
    {
        $this->seedOtp('+8801722222222', '111000');

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+8801722222222',
            'code' => '111000',
            'role' => UserRole::DRIVER,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.user.role', UserRole::DRIVER);
        $this->assertDatabaseHas('users', [
            'phone' => '+8801722222222',
            'role' => UserRole::DRIVER,
        ]);
    }

    public function test_verify_otp_rejects_wrong_code(): void
    {
        $this->seedOtp('+8801711111111', '111111');

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+8801711111111',
            'code' => '000000',
            'role' => UserRole::PASSENGER,
        ]);

        $response->assertStatus(400);
    }

    public function test_jwt_token_can_access_protected_profile_endpoint(): void
    {
        $headers = $this->authHeaders($this->passenger);

        $response = $this->getJson('/api/v1/profile', $headers);

        $response->assertOk();
        // The profile endpoint returns a nested shape:
        //   { data: { user: {...}, emergency_contacts: [...] } }
        // The top-level `data` wrapper comes from ApiResponse::success()
        // and the nested `user` shape is produced by PublicUserResource.
        // Pinned here so a future refactor that flattens the response
        // breaks this test first.
        $response->assertJsonPath('data.user.phone', $this->passenger->phone);
    }

    public function test_profile_endpoint_returns_json_401_without_token(): void
    {
        $response = $this->getJson('/api/v1/profile');

        // JSON 401 — confirms Authenticate middleware does not redirect to
        // the web login route, which would have produced an HTML response.
        $response->assertStatus(401);
        $this->assertIsArray($response->json());
        $this->assertNotEmpty($response->json());
    }
}
