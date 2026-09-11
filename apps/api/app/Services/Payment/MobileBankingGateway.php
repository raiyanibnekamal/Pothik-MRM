<?php

namespace App\Services\Payment;

/**
 * Common contract for a mobile-banking payment gateway (bKash, Nagad, Rocket,
 * Upay, etc).
 *
 * The lifecycle is two-step for every provider we target:
 *   1. create($amount, $reference, $callbackUrl)  -> returns a payment URL and
 *      provider-side payment id. The mobile app opens the URL for the user to
 *      confirm with their MNO PIN.
 *   2. execute($providerPaymentId)                -> after the callback/webhook
 *      resolves the payment, the caller asks the gateway for the final status
 *      (completed / failed / cancelled). If completed the ride is finalized
 *      and the commission debt is recorded.
 *
 * For local/test the NullGateway implements this without making any HTTP calls.
 * Real providers always return false on network/4xx/5xx so callers can mark
 * the transaction as failed without throwing.
 */
interface MobileBankingGateway
{
    /**
     * Initiate a charge.
     *
     * @param  float   $amount         Amount in BDT
     * @param  string  $reference      Idempotent merchant reference (e.g. ride id)
     * @param  string  $callbackUrl    Where the MNO redirects after confirmation
     * @return array{
     *     ok: bool,
     *     provider_payment_id?: string,
     *     payment_url?: string,
     *     error?: string
     * }
     */
    public function create(float $amount, string $reference, string $callbackUrl): array;

    /**
     * Look up the final status of a previously-created payment.
     *
     * @param  string  $providerPaymentId  Value returned from create()
     * @return array{
     *     ok: bool,
     *     status?: string,           // 'completed' | 'failed' | 'cancelled' | 'pending'
     *     trx_id?: string,           // Gateway's own transaction reference
     *     error?: string
     * }
     */
    public function execute(string $providerPaymentId): array;

    /**
     * Stable identifier for this driver — used by PaymentManager to resolve it
     * from config and by tests to fake it.
     */
    public function name(): string;
}
