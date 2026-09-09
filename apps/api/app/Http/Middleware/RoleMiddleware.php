<?php

namespace App\Http\Middleware;

use App\Constants\ErrorCodes;
use App\Support\ApiResponse;
use Closure;
use Illuminate\Http\Request;

class RoleMiddleware
{
    public function handle(Request $request, Closure $next, ...$roles)
    {
        $user = $request->user();

        if (!$user) {
            return ApiResponse::error(ErrorCodes::UNAUTHORIZED, 'Unauthorized', 401);
        }

        if (!in_array($user->role, $roles, true)) {
            return ApiResponse::error(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        return $next($request);
    }
}
