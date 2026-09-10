<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Exceptions\ApiException;
use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Str;
use Tymon\JWTAuth\Facades\JWTAuth;

class TokenService
{
    public function issueTokens(User $user): array
    {
        $accessToken = JWTAuth::fromUser($user);
        $payload = JWTAuth::setToken($accessToken)->getPayload();
        $jti = $payload->get('jti');

        $refreshPlain = Str::random(64);
        RefreshToken::create([
            'user_id' => $user->id,
            'token_hash' => hash('sha256', $refreshPlain),
            'jti' => $jti,
            'expires_at' => now()->addDays(7),
        ]);

        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshPlain,
            'token_type' => 'Bearer',
            'expires_in' => config('jwt.ttl') * 60,
            'user' => $this->formatUser($user),
        ];
    }

    public function refresh(string $refreshToken): array
    {
        $hash = hash('sha256', $refreshToken);
        $stored = RefreshToken::where('token_hash', $hash)
            ->where('expires_at', '>', now())
            ->first();

        if (!$stored) {
            throw new ApiException(ErrorCodes::UNAUTHORIZED, 'Invalid refresh token', 401);
        }

        $user = User::find($stored->user_id);
        if (!$user || $user->is_blocked) {
            throw new ApiException(ErrorCodes::BLOCKED, 'Account blocked', 403);
        }

        if ($stored->jti) {
            Redis::setex('jwt:blacklist:' . $stored->jti, config('jwt.ttl') * 60, '1');
        }

        $stored->delete();

        return $this->issueTokens($user);
    }

    public function logout(User $user, ?string $jti = null): void
    {
        RefreshToken::where('user_id', $user->id)->delete();

        if ($jti) {
            Redis::setex('jwt:blacklist:' . $jti, config('jwt.ttl') * 60, '1');
        }

        try {
            JWTAuth::invalidate(JWTAuth::getToken());
        } catch (\Throwable) {
            // Token may already be expired
        }
    }

    public function isBlacklisted(?string $jti): bool
    {
        if (!$jti) {
            return false;
        }

        return (bool) Redis::get('jwt:blacklist:' . $jti);
    }

    private function formatUser(User $user): array
    {
        return [
            'id' => $user->id,
            'phone' => $user->phone,
            'email' => $user->email,
            'name' => $user->name,
            'role' => $user->role,
            'language' => $user->language,
            'photo_url' => $user->photo_url,
            'is_profile_complete' => !empty($user->name),
        ];
    }
}
