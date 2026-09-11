<?php

namespace Tests\Feature;

use App\Services\Payment\BkashGateway;
use App\Services\Payment\MobileBankingGateway;
use App\Services\Payment\NagadGateway;
use App\Services\Payment\NullGateway;
use App\Services\Payment\PaymentManager;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

/**
 * Regression coverage for the pluggable mobile-banking gateway introduced in
 * Phase 0b.
 *
 * Pins four contracts:
 *   1. Default driver resolves to NullGateway in testing env (so existing
 *      cash-only flow keeps working).
 *   2. PaymentManager routes a named driver to the right class.
 *   3. BkashGateway / NagadGateway issues a request against the expected
 *      endpoint with the right payload, and returns the parsed result on 2xx.
 *   4. Both gateways return ok=false when credentials are missing, so a
 *      misconfigured production deploy fails loudly instead of dropping the
 *      charge.
 */
class PaymentGatewayTest extends ApiTestCase
{
    use RefreshDatabase;

    public function test_default_driver_in_testing_is_null_gateway(): void
    {
        config()->set('payment.default', null); // fall back to "null"

        /** @var PaymentManager $manager */
        $manager = $this->app->make(PaymentManager::class);
        $driver = $manager->driver();

        $this->assertInstanceOf(NullGateway::class, $driver);
        $this->assertInstanceOf(MobileBankingGateway::class, $driver);
        $this->assertSame('null', $driver->name());
    }

    public function test_named_driver_resolves_to_bkash_gateway(): void
    {
        config()->set('payment.providers.bkash', [
            'username' => 'test_user',
            'password' => 'test_pw',
            'app_key' => 'test_app_key',
            'app_secret' => 'test_app_secret',
            'base_url' => 'https://tokenized.pay.bka.sh/v1.2.0-beta',
            'timeout' => 5,
        ]);

        $driver = $this->app->make(PaymentManager::class)->driver('bkash');

        $this->assertInstanceOf(BkashGateway::class, $driver);
        $this->assertSame('bkash', $driver->name());
    }

    public function test_named_driver_resolves_to_nagad_gateway(): void
    {
        config()->set('payment.providers.nagad', [
            'merchant_id' => 'm_test',
            'merchant_key' => 'k_test',
            'base_url' => 'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0',
            'timeout' => 5,
        ]);

        $driver = $this->app->make(PaymentManager::class)->driver('nagad');

        $this->assertInstanceOf(NagadGateway::class, $driver);
        $this->assertSame('nagad', $driver->name());
    }

    public function test_unknown_driver_throws(): void
    {
        $this->expectException(\RuntimeException::class);

        $this->app->make(PaymentManager::class)->driver('rocket');
    }

    public function test_bkash_gateway_returns_false_when_credentials_missing(): void
    {
        config()->set('payment.providers.bkash', [
            'username' => '',
            'password' => '',
            'app_key' => '',
            'app_secret' => '',
            'base_url' => 'https://tokenized.pay.bka.sh/v1.2.0-beta',
            'timeout' => 5,
        ]);

        /** @var BkashGateway $driver */
        $driver = $this->app->make(PaymentManager::class)->driver('bkash');

        $result = $driver->create(120.50, 'ride-test-001', 'https://example.test/cb');

        $this->assertFalse($result['ok']);
        $this->assertArrayHasKey('error', $result);
    }

    public function test_bkash_gateway_calls_token_grant_then_create(): void
    {
        // Fake both calls — token grant then checkout/create.
        Http::fake([
            'tokenized.pay.bka.sh/*' => Http::sequence()
                ->push(['id_token' => 'jwt_abc', 'statusCode' => '0000'], 200)
                ->push([
                    'statusCode' => '0000',
                    'paymentID' => 'TR0011abc',
                    'bkashURL' => 'https://checkout.pay.bka.sh/redirect/TR0011abc',
                ], 200),
        ]);

        config()->set('payment.providers.bkash', [
            'username' => 'user',
            'password' => 'pw',
            'app_key' => 'ak',
            'app_secret' => 'as',
            'base_url' => 'https://tokenized.pay.bka.sh/v1.2.0-beta',
            'timeout' => 5,
        ]);

        /** @var BkashGateway $driver */
        $driver = $this->app->make(PaymentManager::class)->driver('bkash');

        $result = $driver->create(250.00, 'ride-test-002', 'https://example.test/cb');

        $this->assertTrue($result['ok']);
        $this->assertSame('TR0011abc', $result['provider_payment_id']);
        $this->assertStringContainsString('TR0011abc', $result['payment_url']);

        Http::assertSent(function ($request) {
            $url = $request->url();
            if (str_ends_with($url, '/tokenized/checkout/token/grant')) {
                return $request->method() === 'POST'
                    && $request->header('username')[0] === 'user';
            }
            if (str_ends_with($url, '/tokenized/checkout/create')) {
                $data = $request->data();
                return $request->method() === 'POST'
                    && ($data['amount'] ?? null) === '250.00'
                    && ($data['merchantInvoiceNumber'] ?? null) === 'ride-test-002';
            }
            return false;
        });
    }

    public function test_bkash_gateway_returns_false_on_5xx(): void
    {
        Http::fake([
            'tokenized.pay.bka.sh/*' => Http::response('upstream down', 502),
        ]);

        config()->set('payment.providers.bkash', [
            'username' => 'user',
            'password' => 'pw',
            'app_key' => 'ak',
            'app_secret' => 'as',
            'base_url' => 'https://tokenized.pay.bka.sh/v1.2.0-beta',
            'timeout' => 5,
        ]);

        /** @var BkashGateway $driver */
        $driver = $this->app->make(PaymentManager::class)->driver('bkash');

        $result = $driver->create(100.00, 'ride-test-003', 'https://example.test/cb');

        $this->assertFalse($result['ok']);
    }

    public function test_nagad_gateway_returns_false_when_credentials_missing(): void
    {
        config()->set('payment.providers.nagad', [
            'merchant_id' => '',
            'merchant_key' => '',
            'base_url' => 'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0',
            'timeout' => 5,
        ]);

        $driver = $this->app->make(PaymentManager::class)->driver('nagad');

        $result = $driver->create(80.00, 'ride-test-004', 'https://example.test/cb');

        $this->assertFalse($result['ok']);
        $this->assertArrayHasKey('error', $result);
    }

    public function test_nagad_gateway_calls_initialize(): void
    {
        Http::fake([
            '*sandbox.mynagad.com*' => Http::response([
                'status' => 'Success',
                'paymentReferenceId' => 'nagad-ref-9001',
                'callBackUrl' => 'https://sandbox.mynagad.com/redirect?nref=nagad-ref-9001',
            ], 200),
        ]);

        config()->set('payment.providers.nagad', [
            'merchant_id' => 'm_test',
            'merchant_key' => 'k_test',
            'base_url' => 'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0',
            'timeout' => 5,
        ]);

        $driver = $this->app->make(PaymentManager::class)->driver('nagad');

        $result = $driver->create(150.00, 'ride-test-005', 'https://example.test/cb');

        $this->assertTrue($result['ok']);
        $this->assertSame('nagad-ref-9001', $result['provider_payment_id']);
        $this->assertStringContainsString('nagad-ref-9001', $result['payment_url']);
    }

    public function test_null_gateway_simulates_create_and_execute(): void
    {
        $driver = new NullGateway();

        $create = $driver->create(99.00, 'ride-null-1', 'https://example.test/cb');
        $this->assertTrue($create['ok']);
        $this->assertStringStartsWith('mock_', $create['provider_payment_id']);
        $this->assertNotEmpty($create['payment_url']);

        $execute = $driver->execute($create['provider_payment_id']);
        $this->assertTrue($execute['ok']);
        $this->assertSame('completed', $execute['status']);
        $this->assertStringStartsWith('mock_trx_', $execute['trx_id']);
    }
}
