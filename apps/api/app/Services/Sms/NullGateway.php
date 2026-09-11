<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Log;

/**
 * No-op gateway used in local and testing environments.
 *
 * Logs the would-be SMS so devs can verify flow without contacting a real
 * provider and so the Pest suite can assert the call shape with Http::fake().
 */
class NullGateway implements SmsGateway
{
    public function send(string $phone, string $message): bool
    {
        Log::info('SMS sent (mock)', [
            'phone' => substr($phone, 0, 7) . '****',
            'message' => $message,
        ]);

        return true;
    }

    public function name(): string
    {
        return 'null';
    }
}
