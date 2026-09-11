<?php

namespace App\Services\Payment;

use Illuminate\Support\Facades\Log;

/**
 * No-op mobile-banking gateway for local/test.
 *
 * Simulates the two-step flow without contacting any real MNO:
 *   - create() returns a deterministic provider_payment_id (hash of reference)
 *     and a dummy payment URL.
 *   - execute() always reports 'completed' so callers can move on.
 *
 * Real providers are wired the same way but call the upstream API and parse
 * the response.
 */
class NullGateway implements MobileBankingGateway
{
    public function create(float $amount, string $reference, string $callbackUrl): array
    {
        $providerId = 'mock_' . substr(hash('sha256', $reference . $amount), 0, 16);

        Log::info('Payment create (mock)', [
            'amount' => $amount,
            'reference' => $reference,
            'provider_payment_id' => $providerId,
        ]);

        return [
            'ok' => true,
            'provider_payment_id' => $providerId,
            'payment_url' => "https://example.test/mobile-banking/mock/{$providerId}",
        ];
    }

    public function execute(string $providerPaymentId): array
    {
        Log::info('Payment execute (mock)', ['provider_payment_id' => $providerPaymentId]);

        return [
            'ok' => true,
            'status' => 'completed',
            'trx_id' => 'mock_trx_' . substr(hash('sha256', $providerPaymentId), 0, 12),
        ];
    }

    public function name(): string
    {
        return 'null';
    }
}
