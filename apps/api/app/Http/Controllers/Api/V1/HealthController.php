<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\ApiResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

class HealthController extends Controller
{
    public function check()
    {
        $dbOk = false;
        $redisOk = false;

        try {
            DB::connection()->getPdo();
            $dbOk = true;
        } catch (\Throwable) {
        }

        try {
            Redis::ping();
            $redisOk = true;
        } catch (\Throwable) {
        }

        $status = ($dbOk && $redisOk) ? 'ok' : 'degraded';

        return ApiResponse::success([
            'status' => $status,
            'db' => $dbOk ? 'up' : 'down',
            'redis' => $redisOk ? 'up' : 'down',
            'timestamp' => now()->toIso8601String(),
        ], null, $status === 'ok' ? 200 : 503);
    }
}
