<?php

namespace App\Http\Controllers\Api\V1;

use App\Constants\ErrorCodes;
use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use App\Models\User;
use App\Services\OtpService;
use App\Services\TokenService;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Tymon\JWTAuth\Facades\JWTAuth;

class AuthController extends Controller
{
    public function __construct(
        private OtpService $otpService,
        private TokenService $tokenService
    ) {}

    public function requestOtp(Request $request)
    {
        $request->validate(['phone' => 'required|string']);

        $this->otpService->requestOtp($request->phone);

        return ApiResponse::success(null, 'OTP sent');
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'phone' => 'required|string',
            'code' => 'required|string|size:6',
            'role' => 'nullable|in:passenger,driver',
        ]);

        $this->otpService->verifyOtp($request->phone, $request->code);

        // S0.2 — Role assignment is one-shot on first signup only. Existing
        // users keep their original role so a passenger can never elevate
        // to driver just by passing `role=driver` on a verify call. Driver
        // onboarding for an existing passenger must go through the dedicated
        // driver KYC flow.
        $user = User::firstOrCreate(
            ['phone' => $request->phone],
            ['role' => $request->role ?? UserRole::PASSENGER, 'language' => 'bn']
        );

        if ($user->is_blocked) {
            throw new ApiException(ErrorCodes::BLOCKED, 'Account blocked', 403);
        }

        // Intentional: no $user->update([... 'role' => ...]) on existing users.

        return ApiResponse::success($this->tokenService->issueTokens($user));
    }

    public function refresh(Request $request)
    {
        $request->validate(['refresh_token' => 'required|string']);

        return ApiResponse::success(
            $this->tokenService->refresh($request->refresh_token)
        );
    }

    public function logout(Request $request)
    {
        $jti = null;
        try {
            $jti = JWTAuth::parseToken()->getPayload()->get('jti');
        } catch (\Throwable) {
        }

        $this->tokenService->logout($request->user(), $jti);

        return ApiResponse::success(null, 'Logged out');
    }

    public function adminLogin(Request $request)
    {
        $key = 'admin-login:' . $request->ip();
        if (RateLimiter::tooManyAttempts($key, 6)) {
            throw new ApiException(ErrorCodes::OTP_RATE_LIMIT, 'Too many attempts', 429);
        }
        RateLimiter::hit($key, 60);

        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !UserRole::isAdmin($user->role) || !Hash::check($request->password, $user->password)) {
            throw new ApiException(ErrorCodes::UNAUTHORIZED, 'Invalid credentials', 401);
        }

        if ($user->is_blocked) {
            throw new ApiException(ErrorCodes::BLOCKED, 'Account blocked', 403);
        }

        RateLimiter::clear($key);

        return ApiResponse::success($this->tokenService->issueTokens($user));
    }

    public function registerDeviceToken(Request $request)
    {
        $request->validate([
            'token' => 'required|string',
            'platform' => 'nullable|string|in:android,ios,web',
        ]);

        DeviceToken::updateOrCreate(
            ['user_id' => $request->user()->id, 'token' => $request->token],
            ['platform' => $request->platform]
        );

        return ApiResponse::success(null, 'Device token registered');
    }
}
