<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Broadcaster
    |--------------------------------------------------------------------------
    |
    | This option controls the default broadcaster that will be used by the
    | framework when an event needs to be broadcast. You may set this to
    | any of the connections defined in the "connections" array below.
    |
    | Supported: "pusher", "ably", "reverb", "redis", "log", "null"
    |
    | The Pusher + Reverb connection blocks are pre-wired but remain
    | inactive until the matching broadcast driver is installed via Composer
    | and BROADCAST_DRIVER points at it. The default stays "log" in
    | development so events are visible without a running broker — set to
    | "null" in unit tests where Event::fake() is used.
    |
    */

    'default' => env('BROADCAST_DRIVER', env('APP_ENV') === 'testing' ? 'null' : 'log'),

    /*
    |--------------------------------------------------------------------------
    | Broadcast Connections
    |--------------------------------------------------------------------------
    |
    | Here you may define all of the broadcast connections that will be used
    | to broadcast events to other systems or over websockets. Samples of
    | each available type of connection are provided inside this array.
    |
    */

    'connections' => [

        'ably' => [
            'driver' => 'ably',
            'key' => env('ABLY_KEY'),
        ],

        'redis' => [
            'driver' => 'redis',
            'connection' => 'default',
        ],

        // The "log" driver is intentionally the default during development.
        // Every ShouldBroadcast event is JSON-encoded into storage/logs/laravel.log
        // so we can see the full payload shape (channel + event name + body)
        // without standing up a websocket broker. In CI, BROADCAST_DRIVER=null
        // combined with Event::fake() is used so we can assert exact
        // payload semantics without polluting the log file.
        'log' => [
            'driver' => 'log',
        ],

        // Reverb connection block is pre-wired (PHP 8.2+ install not yet
        // available on this server, but the env keys + connection shape are
        // in place so flipping on Reverb later is a one-step env change).
        //
        // To activate:
        //   1. composer require laravel/reverb   (requires PHP 8.2+)
        //   2. php artisan reverb:install
        //   3. Uncomment App\Providers\BroadcastServiceProvider in config/app.php
        //   4. Set BROADCAST_DRIVER=reverb + fill the REVERB_* env keys
        //   5. Run `php artisan reverb:start` (or the new Docker 'reverb' service)
        'reverb' => [
            'driver' => 'reverb',
            'key' => env('REVERB_APP_KEY'),
            'secret' => env('REVERB_APP_SECRET'),
            'app_id' => env('REVERB_APP_ID'),
            'options' => [
                'host' => env('REVERB_HOST', '0.0.0.0'),
                'port' => env('REVERB_PORT', 8080),
                'scheme' => env('REVERB_SCHEME', 'http'),
                'useTLS' => env('REVERB_SCHEME', 'http') === 'https',
                'verify' => env('REVERB_TLS_VERIFY', true),
            ],
            'client_options' => [],
        ],

        // Pusher connection works with both hosted pusher.com and a self-hosted
        // pusher-compatible broker (Soketi). The mobile/admin clients can point
        // at the same WS endpoint whether it's pusher-hosted or self-hosted,
        // which keeps Phase 0d/1 mobile work broker-agnostic.
        'pusher' => [
            'driver' => 'pusher',
            'key' => env('PUSHER_APP_KEY'),
            'secret' => env('PUSHER_APP_SECRET'),
            'app_id' => env('PUSHER_APP_ID'),
            'options' => [
                'cluster' => env('PUSHER_APP_CLUSTER'),
                'host' => env('PUSHER_HOST'),
                'port' => (int) env('PUSHER_PORT', 443),
                'scheme' => env('PUSHER_SCHEME', 'https'),
                'encrypted' => env('PUSHER_SCHEME', 'https') === 'https',
                'useTLS' => env('PUSHER_SCHEME', 'https') === 'https',
            ],
            'client_options' => [],
        ],

        'null' => [
            'driver' => 'null',
        ],

        // TestBroadcaster — same channel-closure semantics as Pusher/Reverb
        // but with no socket plumbing. Driven by BROADCAST_DRIVER=test in
        // phpunit.xml. Lives in app/Broadcasting so future admin + mobile
        // suites can pick it up via the same alias.
        'test' => [
            'driver' => 'test',
        ],

    ],

];
