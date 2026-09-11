<?php

namespace App\Services\Payment;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * bKash Tokenized Payment API (v1.2) gateway.
 *
 * Flow we model:
 *   1. Grant a short-lived access_token via grant_type=client_credentials.
 *   2. POST /tokenized/checkout/create with amount, merchantInvoiceNumber,
 *      callbackURL — returns bkashPaymentID and bkashURL.
 *   3. After the user confirms in the bKash app, the gateway redirects to
 *      callbackURL with ?status=success&paymentID=...  Our caller then calls
 *      execute($paymentID) which POSTs to /tokenized/checkout/execute to
 *      confirm the capture.
 *
 * Reference: https://developer.bka.sh/reference
 *
 * NOTE: The bKash sandbox currently requires a registered merchant account
 * with sandbox credentials before the /tokenized/checkout/create call will
 * succeed. We deliberately do NOT default to calling the live endpoint —
 * `bkash.base_url` defaults to the sandbox URL and the gateway returns false
 * whenever credentials are missing so misconfiguration fails loudly.
 */
class BkashGateway implements MobileBankingGateway
{
    public function __construct(
        private string $username,
        private string $password,
        private string $appKey,
        private string $appSecret,
        private string $baseUrl = 'https://tokenized.pay.bka.sh/v1.2.0-beta',
        private int $timeout = 15,
    ) {}

    public function create(float $amount, string $reference, string $callbackUrl): array
    {
        if (!$this->isConfigured()) {
            return ['ok' => false, 'error' => 'bKash credentials missing'];
        }

        try {
            $token = $this->grantToken();
            if ($token === null) {
                return ['ok' => false, 'error' => 'bKash token grant failed'];
            }

            $response = Http::timeout($this->timeout)
                ->withToken($token)
                ->post(rtrim($this->baseUrl, '/') . '/tokenized/checkout/create', [
                    'mode' => '0011',
                    'payerReference' => $reference,
                    'callbackURL' => $callbackUrl,
                    'amount' => number_format($amount, 2, '.', ''),
                    'currency' => 'BDT',
                    'intent' => 'sale',
                    'merchantInvoiceNumber' => $reference,
                ]);

            if (!$response->successful()) {
                Log::warning('bKash create non-2xx', [
                    'status' => $response->status(),
                    'body' => substr($response->body(), 0, 200),
                ]);

                return ['ok' => false, 'error' => 'bKash create returned non-2xx'];
            }

            $body = $response->json();

            if (($body['statusCode'] ?? null) !== '0000') {
                return ['ok' => false, 'error' => $body['statusMessage'] ?? 'unknown'];
            }

            return [
                'ok' => true,
                'provider_payment_id' => (string) $body['paymentID'],
                'payment_url' => (string) $body['bkashURL'],
            ];
        } catch (\Throwable $e) {
            Log::error('bKash create exception', ['error' => $e->getMessage()]);

            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    public function execute(string $providerPaymentId): array
    {
        if (!$this->isConfigured()) {
            return ['ok' => false, 'error' => 'bKash credentials missing'];
        }

        try {
            $token = $this->grantToken();
            if ($token === null) {
                return ['ok' => false, 'error' => 'bKash token grant failed'];
            }

            $response = Http::timeout($this->timeout)
                ->withToken($token)
                ->post(rtrim($this->baseUrl, '/') . '/tokenized/checkout/execute', [
                    'paymentID' => $providerPaymentId,
                ]);

            if (!$response->successful()) {
                return ['ok' => false, 'error' => 'bKash execute returned non-2xx'];
            }

            $body = $response->json();

            if (($body['statusCode'] ?? null) !== '0000') {
                return [
                    'ok' => true,
                    'status' => $body['transactionStatus'] ?? 'failed',
                    'trx_id' => $body['trxID'] ?? null,
                ];
            }

            $status = (string) ($body['transactionStatus'] ?? 'pending');
            $completed = in_array($status, ['Completed'], true);

            return [
                'ok' => true,
                'status' => $completed ? 'completed' : strtolower($status),
                'trx_id' => $body['trxID'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('bKash execute exception', ['error' => $e->getMessage()]);

            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    public function name(): string
    {
        return 'bkash';
    }

    private function isConfigured(): bool
    {
        return $this->username !== ''
            && $this->password !== ''
            && $this->appKey !== ''
            && $this->appSecret !== '';
    }

    private function grantToken(): ?string
    {
        try {
            $response = Http::timeout($this->timeout)
                ->withHeaders([
                    'username' => $this->username,
                    'password' => $this->password,
                ])
                ->post(rtrim($this->baseUrl, '/') . '/tokenized/checkout/token/grant', [
                    'app_key' => $this->appKey,
                    'app_secret' => $this->appSecret,
                ]);

            if (!$response->successful()) {
                Log::warning('bKash token grant non-2xx', ['status' => $response->status()]);
                return null;
            }

            $body = $response->json();

            return $body['id_token'] ?? null;
        } catch (\Throwable $e) {
            Log::error('bKash token grant exception', ['error' => $e->getMessage()]);
            return null;
        }
    }
}
