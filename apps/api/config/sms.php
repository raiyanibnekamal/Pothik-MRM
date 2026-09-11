<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default SMS Gateway
    |--------------------------------------------------------------------------
    |
    | The name of the driver to use when sending SMS. Valid options are
    | "null" (local/testing, logs only) or any key of the `providers` array
    | below (e.g. "ssl_wireless").
    |
    */

    'default' => env('SMS_DEFAULT_PROVIDER', 'null'),

    /*
    |--------------------------------------------------------------------------
    | Providers
    |--------------------------------------------------------------------------
    |
    | Each provider entry maps to a concrete SmsGateway implementation. To
    | add a new gateway (BulksmsBD, Robi Aha, Twilio, etc.) drop its config
    | in here and register the case in GatewayManager::driver().
    |
    */

    'providers' => [
        'ssl_wireless' => [
            'sid' => env('SMS_PROVIDERS_SSL_WIRELESS_SID'),
            'token' => env('SMS_PROVIDERS_SSL_WIRELESS_TOKEN'),
            'masking' => env('SMS_PROVIDERS_SSL_WIRELESS_MASKING'),
            'base_url' => env(
                'SMS_PROVIDERS_SSL_WIRELESS_BASE_URL',
                'https://api.sslwireless.com'
            ),
            'timeout' => (int) env('SMS_PROVIDERS_SSL_WIRELESS_TIMEOUT', 10),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | OTP Rate Limit
    |--------------------------------------------------------------------------
    |
    | Phone: max OTP requests per phone number per minute.
    | IP:    max OTP requests per source IP per minute.
    |
    | Both limits are checked. The 4th request from the same phone within a
    | minute returns 429 with error code OTP_RATE_LIMIT.
    |
    */

    'rate_limit' => [
        'phone_per_minute' => (int) env('OTP_RATE_LIMIT_PHONE', 3),
        'ip_per_minute' => (int) env('OTP_RATE_LIMIT_IP', 10),
    ],
];
