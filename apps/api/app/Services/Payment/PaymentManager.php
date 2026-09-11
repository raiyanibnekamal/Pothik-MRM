<?php

namespace App\Services\Payment;

/**
 * Resolves the configured mobile-banking gateway.
 *
 * Drivers are resolved from `config('payment.providers')`. The `null` driver
 * is always available for local/test — it simulates the two-step flow
 * without contacting any real MNO.
 *
 * Unknown names throw so a misconfigured production environment fails fast
 * instead of silently dropping money.
 */
class PaymentManager
{
    public function __construct(private array $config) {}

    public function driver(?string $name = null): MobileBankingGateway
    {
        $name ??= $this->config['default'] ?? 'null';

        if ($name === 'null') {
            return new NullGateway();
        }

        $providerConfig = $this->config['providers'][$name] ?? null;

        if ($providerConfig === null) {
            throw new \RuntimeException(
                "Payment provider [{$name}] is not configured. "
                . "Check config/payment.php and PAYMENT_PROVIDERS_{$name} env keys."
            );
        }

        return match ($name) {
            'bkash' => new BkashGateway(
                username: (string) ($providerConfig['username'] ?? ''),
                password: (string) ($providerConfig['password'] ?? ''),
                appKey: (string) ($providerConfig['app_key'] ?? ''),
                appSecret: (string) ($providerConfig['app_secret'] ?? ''),
                baseUrl: (string) ($providerConfig['base_url'] ?? 'https://tokenized.pay.bka.sh/v1.2.0-beta'),
                timeout: (int) ($providerConfig['timeout'] ?? 15),
            ),
            'nagad' => new NagadGateway(
                merchantId: (string) ($providerConfig['merchant_id'] ?? ''),
                merchantKey: (string) ($providerConfig['merchant_key'] ?? ''),
                baseUrl: (string) ($providerConfig['base_url'] ?? 'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0'),
                timeout: (int) ($providerConfig['timeout'] ?? 15),
            ),
            default => throw new \RuntimeException(
                "Payment driver [{$name}] is not registered. "
                . "Add it to PaymentManager::driver()."
            ),
        };
    }
}
