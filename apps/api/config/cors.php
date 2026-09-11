<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Here you may configure your settings for cross-origin resource sharing
    | or "CORS". This determines what cross-origin operations may execute
    | in web browsers. You are free to adjust these settings as needed.
    |
    | To learn more: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    // Locked from '*' to explicit origins. Comma-separated list via the
    // `CORS_ALLOWED_ORIGINS` env var (see apps/api/.env.example:47). Defaults
    // cover local dev only; staging/prod MUST override with the real admin
    // panel origin(s), e.g.:
    //   CORS_ALLOWED_ORIGINS=https://admin.bdrideshare.com
    'allowed_origins' => array_filter(array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost:5173,http://localhost:5174,http://localhost:5175,http://127.0.0.1:5173')))),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
