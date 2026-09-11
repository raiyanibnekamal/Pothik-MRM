<?php

namespace App\Services\Sms;

/**
 * Resolves the configured SMS gateway.
 *
 * Drivers are resolved from `config('sms.providers')`. Unknown names throw so
 * a misconfigured production environment fails fast instead of silently
 * dropping messages. The `null` driver is always available for local/test.
 */
class GatewayManager
{
    public function __construct(private array $config) {}

    public function driver(?string $name = null): SmsGateway
    {
        $name ??= $this->config['default'] ?? 'null';

        if ($name === 'null') {
            return new NullGateway();
        }

        $providerConfig = $this->config['providers'][$name] ?? null;

        if ($providerConfig === null) {
            throw new \RuntimeException(
                "SMS provider [{$name}] is not configured. "
                . "Check config/sms.php and SMS_PROVIDERS_{$name} env keys."
            );
        }

        return match ($name) {
            'ssl_wireless' => new SslWirelessGateway(
                sid: (string) ($providerConfig['sid'] ?? ''),
                token: (string) ($providerConfig['token'] ?? ''),
                baseUrl: (string) ($providerConfig['base_url'] ?? 'https://api.sslwireless.com'),
                masking: (string) ($providerConfig['masking'] ?? ''),
                timeout: (int) ($providerConfig['timeout'] ?? 10),
            ),
            default => throw new \RuntimeException(
                "SMS driver [{$name}] is not registered. "
                . "Add it to GatewayManager::driver()."
            ),
        };
    }
}
