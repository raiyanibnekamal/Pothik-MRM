<?php

namespace Tests\Feature;

use App\Services\Fcm\FcmService;
use App\Services\Fcm\NullFcmService;
use App\Services\Fcm\FirebaseFcmService;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Regression coverage for the FCM gateway contract introduced in Phase 0b +
 * the Phase 0d JWT signer integration.
 *
 * Pins the contract surface:
 *   1. Default binding resolves to NullFcmService (so unrelated test runs
 *      don't accidentally hit FCM).
 *   2. NullFcmService.sendToUser / sendToToken both return true and log.
 *   3. FirebaseFcmService fails closed (returns false) when credentials are
 *      missing or JWT signing is not yet wired — so a misconfigured
 *      production deploy cannot silently lose pushes.
 *   4. When JWT signing IS wired (Phase 0d), the gateway hits
 *      oauth2.googleapis.com/token with the standard JWT-bearer grant and
 *      uses the returned access_token on the messages:send POST.
 */
class FcmServiceTest extends ApiTestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Every test starts with a cold OAuth-token cache so high-volume test
        // runs don't accidentally share minted tokens across cases.
        Cache::forget('fcm:oauth_access_token');
    }

    public function test_default_binding_is_null_fcm_service(): void
    {
        config()->set('fcm.default', 'null');

        $fcm = $this->app->make(FcmService::class);

        $this->assertInstanceOf(NullFcmService::class, $fcm);
        $this->assertSame('null', $fcm->name());
    }

    public function test_named_provider_resolves_to_firebase(): void
    {
        config()->set('fcm.default', 'firebase');
        config()->set('fcm.providers.firebase', [
            'project_id' => 'bd-ride-test',
            'credentials_path' => sys_get_temp_dir() . '/_no-such-firebase-creds.json',
            'timeout' => 5,
        ]);

        $fcm = $this->app->make(FcmService::class);

        $this->assertInstanceOf(FirebaseFcmService::class, $fcm);
        $this->assertSame('firebase', $fcm->name());
    }

    public function test_null_fcm_send_to_user_returns_true(): void
    {
        /** @var NullFcmService $fcm */
        $fcm = $this->app->make(FcmService::class);

        $this->assertTrue($fcm->sendToUser('user-1', 'Ride assigned', 'Driver is on the way', [
            'ride_id' => 'r-123',
            'type' => 'ride_assigned',
        ]));
    }

    public function test_null_fcm_send_to_token_returns_true(): void
    {
        $fcm = $this->app->make(FcmService::class);

        $this->assertTrue($fcm->sendToToken('device-token-xyz', 'Hello', 'World'));
    }

    public function test_firebase_fcm_returns_false_when_credentials_missing(): void
    {
        $fcm = new FirebaseFcmService(
            projectId: '',
            credentialsPath: '',
            timeout: 5,
        );

        $this->assertFalse($fcm->sendToToken('device-token-xyz', 'Hi', 'There'));
    }

    public function test_firebase_fcm_returns_false_when_credentials_path_unreadable(): void
    {
        $fcm = new FirebaseFcmService(
            projectId: 'bd-ride-test',
            credentialsPath: sys_get_temp_dir() . '/_no-such-firebase-creds.json',
            timeout: 5,
        );

        $this->assertFalse($fcm->sendToToken('device-token-xyz', 'Hi', 'There'));
    }

    public function test_firebase_fcm_returns_false_when_credentials_json_is_malformed(): void
    {
        $badPath = tempnam(sys_get_temp_dir(), 'fcm-bad-');
        file_put_contents($badPath, '{"not": "the expected shape"}');

        $fcm = new FirebaseFcmService(
            projectId: 'bd-ride-test',
            credentialsPath: $badPath,
            timeout: 5,
        );

        $this->assertFalse($fcm->sendToToken('device-token-xyz', 'Hi', 'There'));

        @unlink($badPath);
    }

    public function test_firebase_fcm_would_call_expected_endpoint_when_jwt_is_wired(): void
    {
        // Mint a temporary RSA keypair, drop a service-account JSON in tmp,
        // and exercise the Phase 0d JWT path end-to-end against Http::fake.
        $keyPath = $this->generateServiceAccountKey();
        $result = $this->runSend($keyPath);
        @unlink($keyPath);

        // The OAuth exchange once, then the FCM POST once with a token.
        Http::assertSentCount(2);
        Http::assertSent(function ($request) {
            if ($request->url() !== 'https://oauth2.googleapis.com/token') {
                return false;
            }
            $body = (string) $request->body();
            return str_contains($body, 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer')
                || str_contains($body, 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer');
        });
        Http::assertSent(function ($request) {
            if ($request->url() !== 'https://fcm.googleapis.com/v1/projects/bd-ride-test/messages:send') {
                return false;
            }
            $data = $request->data();
            return ($data['message']['token'] ?? null) === 'device-token-xyz'
                && ($data['message']['notification']['title'] ?? null) === 'Hi'
                && ($data['message']['notification']['body'] ?? null) === 'There'
                && ($request->header('Authorization')[0] ?? '') === 'Bearer fake-access-token';
        });

        $this->assertTrue($result);
    }

    public function test_firebase_fcm_caches_access_token_across_sends(): void
    {
        $keyPath = $this->generateServiceAccountKey();

        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'cached-token', 'expires_in' => 3599, 'token_type' => 'Bearer']),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/bd-ride-test/messages/abc'], 200),
        ]);

        $fcm = new FirebaseFcmService(
            projectId: 'bd-ride-test',
            credentialsPath: $keyPath,
            timeout: 5,
        );

        $this->assertTrue($fcm->sendToToken('device-1', 'A', 'B'));
        $this->assertTrue($fcm->sendToToken('device-2', 'C', 'D'));

        // Three calls — one OAuth exchange, two FCM POSTs.
        Http::assertSentCount(3);
        // The OAuth endpoint should only have been hit ONCE thanks to the cache.
        $oauthHits = 0;
        Http::assertSent(function ($request) use (&$oauthHits) {
            if ($request->url() === 'https://oauth2.googleapis.com/token') {
                $oauthHits++;
            }
            return true;
        });
        $this->assertSame(1, $oauthHits, 'OAuth endpoint should be hit exactly once across cached sends');

        @unlink($keyPath);
    }

    public function test_firebase_fcm_returns_false_when_oauth_exchange_fails(): void
    {
        $keyPath = $this->generateServiceAccountKey();

        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['error' => 'invalid_grant'], 400),
        ]);

        $fcm = new FirebaseFcmService(
            projectId: 'bd-ride-test',
            credentialsPath: $keyPath,
            timeout: 5,
        );

        $this->assertFalse($fcm->sendToToken('device-1', 'A', 'B'));

        @unlink($keyPath);
    }

    /**
     * Generate a service-account JSON shaped file in tmp, returned as an
     * absolute path. The keypair is throwaway — tests never call out to
     * Google's real OAuth endpoint, so the private key isn't sensitive.
     *
     * Uses the firebase/php-jwt test fixture RSA key. That library ships
     * a known-good 2048-bit PKCS#8 PEM at tests/fixtures/rsa-private.pem
     * that signs + verifies cleanly across PHP versions and platforms.
     */
    private function generateServiceAccountKey(): string
    {
        $jwtVendor = base_path('vendor/firebase/php-jwt/tests/fixtures/rsa-private.pem');
        $privateKey = is_file($jwtVendor)
            ? file_get_contents($jwtVendor)
            : self::TEST_RSA_PRIVATE_KEY;

        $path = tempnam(sys_get_temp_dir(), 'fcm-cred-');
        file_put_contents($path, json_encode([
            'type' => 'service_account',
            'project_id' => 'bd-ride-test',
            'client_email' => 'fcm@bd-ride-test.iam.gserviceaccount.com',
            'private_key' => $privateKey,
        ]));

        return $path;
    }

    /**
     * Fallback RSA-2048 PKCS#8 PEM. Generated once with openssl and pinned
     * here so the test still works even if firebase/php-jwt's test fixtures
     * are reorganised in a future release.
     */
    private const TEST_RSA_PRIVATE_KEY = <<<'PEM'
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCzoLKFRwU1h2xS
voLRxeW9na4X/KXHv5uIxwqrt9YSW7hvouL2ib5o07Q1TY8ZjsP/rr3wqAXvgBWT
Yt/tQQ053ySdoZdPWp0cpbNs4JX6yWWwuZdBmT8G20DourwiR5pcY0RG0c8R7WpH
qjyN2V5Q5a2wyN85aJN/n+4MucWIARwOagsrUMR+CKeEtR3GeUwQzSv3T8X+kXTS
bxM0qfVDoVShnqrv6BeD4j+YXUZnhT2LQF4s6ELOlPGyU8CRCbkLOU2QwnaRQx7B
//R5BSP68GHmQmlxrCenMrj4wiJfY4mc+H2a+FYF08FDsYM4t+LGdJUHa6Xq9Ib3
snkE690XAgMBAAECggEAftds+FwMO55jSZKpwgOilWDw/JM1ZXXSGKWkzVlFWzVV
ac91wW3G/TLxP+qCsCN2F+iGy5d6iYLCuY7KXTjgZAtESeM/e5Oa+g2wQ6PbhHoO
ytpjCrlyHh9ZGH40N2ikgbS/E9s4A4rIz85QcEIcLbfiDMHrjxhff3GpoWbVK5Gd
RlWS8lVURJYPFJpLsSP8gFrpUkNJftm7hL9nZeegfVmiUR68WFr7LoaZdQS09/Qm
AbbW7m8u9fH05betLAtIlE73EpJgfaaqomThSsRdcKKbP1FRz+y6O2/Fa+sJLgeV
cT2BYex0NjJZlHldULZfWJeIEnlEXaT6uWBhkgseIQKBgQDng5m9nSNojUfEY6Yl
qWqFhxtzPOJ+3vwEi7hxrtoAlaz8NdE2FPTUPxymlNLRfigyjcvXAlVXXECyQJux
McSaAUlMOZAnSxKzTFm63lNra0M0a5uN6XU+6VcunSEwKydEvnEw18CPWwhjNFbh
eCcQp+wqCSAM5pQFFMUN8NX/PwKBgQDGoD03e+u3NE5K5ttBpScKORDvvapFy4QT
6jSta3yF8FXROywejanycN9akrmFbQOHHO/7mnWMnU5V0Qof7L+aRGOOfgK1Uwy3
TjivsuRkFdga3t+hKjRO71hMs82Gty39Jo7lpzpaZTwP7KodHFFQx+DNGBDmnKjc
cJcg1BcEKQKBgQDbuOuVqOhtFwEQ455RSivd1K95vEQeMxUuX0jLJC6ktWk66PzI
/jSqp8dSVhaLWtddu3PFeOJ0Cgsg4e6hymET5LqjDFLC6B40avcSQmUbou5idupo
UjTDY4QpqllQNPSM6s3UlD+eDsC0Hn2CeZ1h0m1yK7zuYXwEIoUuyO7g0wKBgA7M
k6MVrZtp30d/aei7OGxvkg560DwBDOc69Q/SyWVlYc+EHCZuobH5rPqfogkJ9VBU
3KCfgpCmi9ajC6ETT7dbzxsn0mXWOUVTI7AboR6/7ekaoAjvDxSuiqK0ZuTZsyiA
ffcofZWMo2wAUzB2Eqz1J4/AcknsdDxweyIsC0b5AoGATrJg1mCN4lpXpuh8mHsx
yHgimcN4Mgn9D7QohAWQGTBYY15Qw89ovpBLpxK7OHh42R2nq8AtrN6iYPtE/rKD
ip5y9fHUxwVehsZ1IXJ8u3SkDVtAG4o6f6TC9Wi+FFZ6ISiFuRXCPVq2XkT2cB8w
X8Da3UGo5N4+qLpPhcnd17k=
-----END PRIVATE KEY-----
PEM;

    private function runSend(string $keyPath): bool
    {
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'fake-access-token', 'expires_in' => 3599, 'token_type' => 'Bearer']),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/bd-ride-test/messages/abc'], 200),
        ]);

        $fcm = new FirebaseFcmService(
            projectId: 'bd-ride-test',
            credentialsPath: $keyPath,
            timeout: 5,
        );

        return $fcm->sendToToken('device-token-xyz', 'Hi', 'There');
    }
}
