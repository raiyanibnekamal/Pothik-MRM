<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Mobile-banking payment gateway
    |--------------------------------------------------------------------------
    |
    | The default provider is resolved by PaymentManager and used whenever the
    | passenger pays via "bKash" or "Nagad" in the mobile app. Per-ride
    | provider selection (e.g. "pay with bKash even though default is Nagad")
    | is supported by PaymentManager::driver($name).
    |
    | `null` is a no-op driver used in local/testing — see NullGateway.
    |
    */

    'default' => env('PAYMENT_DEFAULT_PROVIDER', 'null'),

    'providers' => [
        'bkash' => [
            'username' => env('PAYMENT_PROVIDERS_BKASH_USERNAME'),
            'password' => env('PAYMENT_PROVIDERS_BKASH_PASSWORD'),
            'app_key' => env('PAYMENT_PROVIDERS_BKASH_APP_KEY'),
            'app_secret' => env('PAYMENT_PROVIDERS_BKASH_APP_SECRET'),
            'base_url' => env(
                'PAYMENT_PROVIDERS_BKASH_BASE_URL',
                'https://tokenized.pay.bka.sh/v1.2.0-beta'
            ),
            'timeout' => (int) env('PAYMENT_PROVIDERS_BKASH_TIMEOUT', 15),
        ],

        'nagad' => [
            'merchant_id' => env('PAYMENT_PROVIDERS_NAGAD_MERCHANT_ID'),
            'merchant_key' => env('PAYMENT_PROVIDERS_NAGAD_MERCHANT_KEY'),
            'base_url' => env(
                'PAYMENT_PROVIDERS_NAGAD_BASE_URL',
                'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0'
            ),
            'timeout' => (int) env('PAYMENT_PROVIDERS_NAGAD_TIMEOUT', 15),
        ],
    ],
];
