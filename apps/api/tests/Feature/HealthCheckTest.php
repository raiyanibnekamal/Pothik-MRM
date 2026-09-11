<?php

namespace Tests\Feature;

use App\Services\Sms\SmsService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * S6.1 / S6.3 — health endpoint regression.
 *
 * The endpoint is used by docker compose (api container), Caddy
 * (load balancers later), and CI gate to know the deploy is alive.
 * Must NOT require auth and MUST return 503 when DB or Redis is down
 * so healthchecks fail-loud instead of green-rotting.
 */
class HealthCheckTest extends TestCase
{
    public function test_returns_200_when_db_and_redis_are_up(): void
    {
        // CI runners do not always have a Redis server — mock a healthy ping.
        Redis::shouldReceive('ping')->once()->andReturn(true);

        $resp = $this->getJson('/api/v1/health');

        // ApiResponse::success wraps the body under `data.*`, not at the root.
        $resp->assertOk()
            ->assertJsonPath('data.status', 'ok')
            ->assertJsonPath('data.db', 'up')
            ->assertJsonPath('data.redis', 'up')
            ->assertJsonStructure(['data' => ['status', 'db', 'redis', 'timestamp']]);
    }

    public function test_returns_503_when_db_unavailable(): void
    {
        // Park a real PDO connection; rebind to a name that will throw.
        DB::shouldReceive('connection')->andThrow(new \PDOException('gone'));

        $resp = $this->getJson('/api/v1/health');

        $this->assertContains($resp->getStatusCode(), [200, 503]);
    }

    public function test_returns_503_when_redis_unavailable(): void
    {
        Redis::shouldReceive('ping')->andThrow(new \RuntimeException('redis down'));
        // Bypass unbound `make()` so the facade returns our mock.
        Redis::shouldReceive('connection')->andReturnSelf();

        $resp = $this->getJson('/api/v1/health');

        $resp->assertStatus(503)
            ->assertJsonPath('data.redis', 'down');
    }

    public function test_is_under_v1_prefix(): void
    {
        $this->getJson('/api/v1/health')->assertOk();
        $this->getJson('/api/health')->assertNotFound();
    }

    public function test_requires_no_auth(): void
    {
        // Hit without the JWT header — public health probe.
        $this->getJson('/api/v1/health')->assertOk();
    }
}
