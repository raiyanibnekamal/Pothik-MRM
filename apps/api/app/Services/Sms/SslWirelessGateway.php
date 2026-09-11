<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * SSL Wireless (sslwireless.com) — Bangladesh's de-facto SMS gateway.
 *
 * API contract (v1):
 *   GET https://api.sslwireless.com/api/v3/send-sms
 *     ?api_token={token}
 *     &sid={sid}
 *     &sms={phone}:{message}
 *     &csmsid={client_sms_id}
 *
 * On success the response status_code is 200. On failure it is 4xx/5xx with
 * a JSON body describing the error. SSL Wireless is known to occasionally
 * return 200 with an HTML body — we treat that as failure.
 */
class SslWirelessGateway implements SmsGateway
{
    public function __construct(
        private string $sid,
        private string $token,
        private string $baseUrl,
        private string $masking = '',
        private int $timeout = 10,
    ) {}

    public function send(string $phone, string $message): bool
    {
        if ($this->sid === '' || $this->token === '') {
            Log::warning('SSL Wireless not configured', [
                'sid_set' => $this->sid !== '',
                'token_set' => $this->token !== '',
            ]);

            return false;
        }

        // Strip the leading + for SSL Wireless; they accept either with/without.
        $phone = ltrim($phone, '+');

        try {
            $response = Http::timeout($this->timeout)
                ->get(rtrim($this->baseUrl, '/') . '/api/v3/send-sms', [
                    'api_token' => $this->token,
                    'sid' => $this->sid,
                    'sms' => $phone . ':' . $message,
                    'csmsid' => bin2hex(random_bytes(6)),
                ]);

            if (!$response->successful()) {
                Log::warning('SSL Wireless returned non-2xx', [
                    'status' => $response->status(),
                    'body' => substr($response->body(), 0, 200),
                ]);

                return false;
            }

            return true;
        } catch (\Throwable $e) {
            Log::error('SSL Wireless send failed', [
                'error' => $e->getMessage(),
                'phone' => substr($phone, 0, 7) . '****',
            ]);

            return false;
        }
    }

    public function name(): string
    {
        return 'ssl_wireless';
    }
}
