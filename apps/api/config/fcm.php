<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Firebase Cloud Messaging
    |--------------------------------------------------------------------------
    |
    | Used by FcmManager to resolve which driver handles push notifications.
    | `null` is the no-op driver (default in local / testing). `firebase`
    | sends through the FCM HTTP v1 endpoint and requires a service-account
    | JSON file.
    |
    | The service-account file is read at runtime by FirebaseFcmService; never
    | commit it. Provide it via a deploy-time secret (K8s Secret, sealed
    | env, etc).
    |
    */

    'default' => env('FCM_DEFAULT_PROVIDER', 'null'),

    'providers' => [
        'firebase' => [
            'project_id' => env('FCM_PROJECT_ID'),
            'credentials_path' => env('FCM_CREDENTIALS_PATH'),
            'timeout' => (int) env('FCM_TIMEOUT', 10),
        ],
    ],
];
