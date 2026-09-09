<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SmsService
{
    public function sendOtp(string $phone, string $code): void
    {
        $this->send($phone, "BD Ride Share OTP: {$code}. Valid 5 minutes.");
    }

    public function sendSos(string $phone, string $message): bool
    {
        return $this->send($phone, $message);
    }

    public function send(string $phone, string $message): bool
    {
        if (app()->environment('local', 'testing')) {
            Log::info('SMS sent (mock)', [
                'phone' => substr($phone, 0, 7) . '****',
                'message' => $message,
            ]);

            return true;
        }

        $url = config('services.sms.url');
        $apiKey = config('services.sms.api_key');

        if (!$url || !$apiKey) {
            Log::warning('SMS gateway not configured');

            return false;
        }

        try {
            $response = Http::timeout(10)
                ->withHeaders(['Authorization' => 'Bearer ' . $apiKey])
                ->post($url, [
                    'to' => $phone,
                    'message' => $message,
                ]);

            return $response->successful();
        } catch (\Throwable $e) {
            Log::error('SMS send failed', ['error' => $e->getMessage()]);

            return false;
        }
    }
}
