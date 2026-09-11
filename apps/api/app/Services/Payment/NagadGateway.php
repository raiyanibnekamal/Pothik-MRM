<?php

namespace App\Services\Payment;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Nagad DCB (Direct Charge to Bill) gateway — Bangladesh Post Office mobile
 * money rail.
 *
 * Lifecycle:
 *   1. POST /check-out/initialize  {merchantId, orderId, amount, ...}  →
 *      response.sensitiveData (encrypted) + paymentReferenceId.
 *   2. The mobile app opens the callBackUrl returned in step 1 for the user
 *      to confirm with their Nagad PIN.
 *   3. We poll or webhook-execute POST /check-out/complete/{paymentRefId}
 *      to confirm the capture.
 *
 * Reference: Nagad Payment Gateway integration manual.
 *
 * As with BkashGateway, we never default to live traffic — `nagad.base_url`
 * defaults to the sandbox endpoint and missing credentials short-circuit
 * the call so a misconfigured production environment fails fast.
 */
class NagadGateway implements MobileBankingGateway
{
    public function __construct(
        private string $merchantId,
        private string $merchantKey,    // shared secret used to sign requests
        private string $baseUrl = 'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0',
        private int $timeout = 15,
    ) {}

    public function create(float $amount, string $reference, string $callbackUrl): array
    {
        if (!$this->isConfigured()) {
            return ['ok' => false, 'error' => 'Nagad credentials missing'];
        }

        try {
            $response = Http::timeout($this->timeout)
                ->withHeaders([
                    'X-KM-Api-Version' => '1.0',
                    'X-KM-Client-Type' => 'PC',
                ])
                ->post(rtrim($this->baseUrl, '/') . '/check-out/initialize', [
                    'merchantId' => $this->merchantId,
                    'orderId' => $reference,
                    'amount' => number_format($amount, 2, '.', ''),
                    'callbackURL' => $callbackUrl,
                ]);

            if (!$response->successful()) {
                Log::warning('Nagad initialize non-2xx', [
                    'status' => $response->status(),
                    'body' => substr($response->body(), 0, 200),
                ]);

                return ['ok' => false, 'error' => 'Nagad initialize returned non-2xx'];
            }

            $body = $response->json();

            if (($body['status'] ?? '') !== 'Success') {
                return ['ok' => false, 'error' => $body['message'] ?? 'unknown'];
            }

            return [
                'ok' => true,
                'provider_payment_id' => (string) $body['paymentReferenceId'],
                'payment_url' => (string) $body['callBackUrl'],
            ];
        } catch (\Throwable $e) {
            Log::error('Nagad initialize exception', ['error' => $e->getMessage()]);

            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    public function execute(string $providerPaymentId): array
    {
        if (!$this->isConfigured()) {
            return ['ok' => false, 'error' => 'Nagad credentials missing'];
        }

        try {
            $response = Http::timeout($this->timeout)
                ->get(rtrim($this->baseUrl, '/') . '/check-out/complete/' . urlencode($providerPaymentId));

            if (!$response->successful()) {
                return ['ok' => false, 'error' => 'Nagad complete returned non-2xx'];
            }

            $body = $response->json();

            $statusRaw = (string) ($body['status'] ?? '');
            $completed = strcasecmp($statusRaw, 'Success') === 0;

            return [
                'ok' => true,
                'status' => $completed ? 'completed' : strtolower($statusRaw ?: 'failed'),
                'trx_id' => $body['issuerPaymentRefNo'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('Nagad complete exception', ['error' => $e->getMessage()]);

            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    public function name(): string
    {
        return 'nagad';
    }

    private function isConfigured(): bool
    {
        return $this->merchantId !== '' && $this->merchantKey !== '';
    }
}
