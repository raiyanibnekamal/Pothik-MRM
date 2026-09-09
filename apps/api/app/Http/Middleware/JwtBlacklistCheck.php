<?php

namespace App\Http\Middleware;

use App\Constants\ErrorCodes;
use App\Services\TokenService;
use App\Support\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Tymon\JWTAuth\Facades\JWTAuth;

class JwtBlacklistCheck
{
    public function handle(Request $request, Closure $next)
    {
        try {
            $payload = JWTAuth::parseToken()->getPayload();
            $jti = $payload->get('jti');

            if (app(TokenService::class)->isBlacklisted($jti)) {
                return ApiResponse::error(ErrorCodes::UNAUTHORIZED, 'Token revoked', 401);
            }
        } catch (\Throwable) {
            // Let auth middleware handle invalid tokens
        }

        return $next($request);
    }
}
