<?php

namespace App\Services\Fcm;

use Illuminate\Support\Facades\Log;

/**
 * No-op FCM implementation used in local and testing environments.
 *
 * Logs the would-be push so devs can verify triggers fire at the right
 * moments without involving Google.
 *
 * No DB read of device_tokens here — log line includes user_id only, so a
 * follow-up Phase will wire device_tokens lookup behind the real driver.
 */
class NullFcmService implements FcmService
{
    public function sendToUser(string $userId, string $title, string $body, array $data = []): bool
    {
        Log::info('FCM push (mock) → user', [
            'user_id' => $userId,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);

        return true;
    }

    public function sendToToken(string $token, string $title, string $body, array $data = []): bool
    {
        Log::info('FCM push (mock) → token', [
            'token_last4' => substr($token, -4),
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);

        return true;
    }

    public function name(): string
    {
        return 'null';
    }
}
