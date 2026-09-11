<?php

namespace App\Providers;

use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\ServiceProvider;

class BroadcastServiceProvider extends ServiceProvider
{
    /**
     * Bootstrap any application services.
     *
     * Registers POST /broadcasting/auth under the api middleware group so
     * JWT-authenticated mobile/admin clients can exchange their token for a
     * per-channel socket signature. The route middleware is aligned with
     * the rest of the v1 API (throttle:api, auth:api) — without auth:api
     * the closure would never see an authenticated user and every channel
     * would return false.
     *
     * The closure-side authorization rules live in routes/channels.php.
     *
     * @return void
     */
    public function boot()
    {
        Broadcast::routes([
            'middleware' => ['api', 'auth:api'],
            'prefix' => 'api/v1',
        ]);

        require base_path('routes/channels.php');
    }
}
