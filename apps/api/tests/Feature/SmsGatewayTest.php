<?php

namespace Tests\Feature;

use App\Services\Sms\GatewayManager;
use App\Services\Sms\NullGateway;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SslWirelessGateway;
use App\Services\SmsService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

/**
 * Regression coverage for the pluggable SMS gateway introduced in Phase 0a.
 *
 * Pins three contracts:
 *   1. Default driver resolves to NullGateway in testing env (so the rest of
 *      the suite keeps working without real network).
 *   2. SslWirelessGateway issues a GET against the expected endpoint with
 *      api_token, sid and the phone+message in the `sms` field, and returns
 *      true on 2xx.
 *   3. SmsService routes through whatever driver the GatewayManager hands
 *      it (so swapping providers in config doesn't require code changes).
 */
class SmsGatewayTest extends ApiTestCase
{
    use RefreshDatabase;

    public function test_default_driver_in_testing_is_null_gateway(): void
    {
        config()->set('sms.default', null); // fall back to the manager's "null" default

        $manager = $this->app->make(GatewayManager::class);
        $driver = $manager->driver();

        $this->assertInstanceOf(NullGateway::class, $driver);
        $this->assertSame('null', $driver->name());
    }

    public function test_named_driver_resolves_to_ssl_wireless_gateway(): void
    {
        config()->set('sms.providers.ssl_wireless', [
            'sid' => 'BD-RIDE-TEST',
            'token' => 'tok_test_123',
            'masking' => 'BDRIDE',
            'base_url' => 'https://api.sslwireless.com',
            'timeout' => 5,
        ]);

        $manager = $this->app->make(GatewayManager::class);
        $driver = $manager->driver('ssl_wireless');

        $this->assertInstanceOf(SslWirelessGateway::class, $driver);
        $this->assertSame('ssl_wireless', $driver->name());
    }

    public function test_ssl_wireless_gateway_calls_expected_endpoint_and_returns_true_on_2xx(): void
    {
        Http::fake([
            'api.sslwireless.com/*' => Http::response('', 200),
        ]);

        config()->set('sms.providers.ssl_wireless', [
            'sid' => 'BD-RIDE-TEST',
            'token' => 'tok_test_123',
            'masking' => '',
            'base_url' => 'https://api.sslwireless.com',
            'timeout' => 5,
        ]);

        /** @var SmsGateway $driver */
        $driver = $this->app->make(GatewayManager::class)->driver('ssl_wireless');

        $ok = $driver->send('+8801711111111', 'Hello from BDRide');

        $this->assertTrue($ok);

        Http::assertSent(function ($request) {
            // Laravel's HTTP client surfaces GET query params both on the URL
            // and on the data() array, so we assert via data() rather than
            // trying to parse the URL string.
            $data = $request->data();

            return $request->method() === 'GET'
                && str_starts_with($request->url(), 'https://api.sslwireless.com/api/v3/send-sms')
                && ($data['api_token'] ?? null) === 'tok_test_123'
                && ($data['sid'] ?? null) === 'BD-RIDE-TEST'
                && ($data['sms'] ?? null) === '8801711111111:Hello from BDRide'
                && ! empty($data['csmsid']);
        });
    }

    public function test_ssl_wireless_gateway_returns_false_on_5xx(): void
    {
        Http::fake([
            'api.sslwireless.com/*' => Http::response('upstream down', 502),
        ]);

        config()->set('sms.providers.ssl_wireless', [
            'sid' => 'BD-RIDE-TEST',
            'token' => 'tok_test_123',
            'base_url' => 'https://api.sslwireless.com',
            'timeout' => 5,
        ]);

        /** @var SmsGateway $driver */
        $driver = $this->app->make(GatewayManager::class)->driver('ssl_wireless');

        $this->assertFalse($driver->send('+8801711111111', 'whatever'));
    }

    public function test_ssl_wireless_gateway_returns_false_when_credentials_missing(): void
    {
        config()->set('sms.providers.ssl_wireless', [
            'sid' => '',
            'token' => '',
            'base_url' => 'https://api.sslwireless.com',
        ]);

        /** @var SmsGateway $driver */
        $driver = $this->app->make(GatewayManager::class)->driver('ssl_wireless');

        $this->assertFalse($driver->send('+8801711111111', 'whatever'));
    }

    public function test_sms_service_routes_through_resolved_driver(): void
    {
        Http::fake([
            'api.sslwireless.com/*' => Http::response('', 200),
        ]);

        config()->set('sms.default', 'ssl_wireless');
        config()->set('sms.providers.ssl_wireless', [
            'sid' => 'BD-RIDE-TEST',
            'token' => 'tok_test_123',
            'base_url' => 'https://api.sslwireless.com',
            'timeout' => 5,
        ]);

        // Re-resolve the binding so the manager picks up the new config.
        $this->app->forgetInstance(GatewayManager::class);
        $this->app->forgetInstance(SmsService::class);

        /** @var SmsService $sms */
        $sms = $this->app->make(SmsService::class);

        $this->assertTrue($sms->send('+8801711111111', 'BD Ride Share OTP: 123456. Valid 5 minutes.'));

        Http::assertSent(fn ($r) => str_starts_with($r->url(), 'https://api.sslwireless.com/api/v3/send-sms'));
    }
}
