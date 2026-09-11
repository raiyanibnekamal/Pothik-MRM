<?php

namespace App\Services\Fcm;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging — HTTP v1 API gateway.
 *
 * Wire shape:
 *   POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send
 *   Authorization: Bearer {oauth2_access_token}
 *   {
 *     "message": {
 *       "token": "<device_token>",        // (or "topic" / "condition")
 *       "notification": {"title": "...", "body": "..."},
 *       "data": {"key": "value", ...}
 *     }
 *   }
 *
 * OAuth2 access tokens are minted from the service-account credentials:
 *   1. Build a self-signed JWT (RS256) with the scope
 *      https://www.googleapis.com/auth/firebase.messaging and a 1-hour expiry.
 *   2. POST the JWT to https://oauth2.googleapis.com/token with
 *      grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer.
 *   3. Cache the resulting access_token in Laravel's cache store for ~55
 *      minutes (slightly less than Google's 60-minute TTL) so a high-volume
 *      push burst doesn't trigger an OAuth roundtrip per message.
 *
 * sendToUser remains a logged no-op because resolving the user's device
 * tokens is the device service's job — this class only sends.
 */
class FirebaseFcmService implements FcmService
{
    private const TOKEN_CACHE_KEY = 'fcm:oauth_access_token';
    private const TOKEN_CACHE_TTL = 3300; // 55 minutes — under Google's 60-min ceiling
    private const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
    private const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    /** @var array{client_email?: string, private_key?: string}|null */
    private ?array $credentials = null;

    public function __construct(
        private string $projectId,
        /** Absolute path to the service-account.json (or empty if not configured). */
        private string $credentialsPath,
        private int $timeout = 10,
    ) {}

    public function sendToUser(string $userId, string $title, string $body, array $data = []): bool
    {
        // device_tokens per-user lookup is the device service's job. Until
        // that lands we log and ack so callers don't need to special-case it.
        Log::info('FCM sendToUser (no token resolution yet)', [
            'user_id' => $userId,
        ]);
        return true;
    }

    public function sendToToken(string $token, string $title, string $body, array $data = []): bool
    {
        if (!$this->isConfigured()) {
            Log::warning('FirebaseFcmService not configured', [
                'project_id_set' => $this->projectId !== '',
                'credentials_path_set' => $this->credentialsPath !== '',
            ]);
            return false;
        }

        $accessToken = $this->mintAccessToken();
        if ($accessToken === null) {
            return false;
        }

        try {
            $response = Http::timeout($this->timeout)
                ->withToken($accessToken)
                ->post(
                    "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send",
                    [
                        'message' => [
                            'token' => $token,
                            'notification' => [
                                'title' => $title,
                                'body' => $body,
                            ],
                            'data' => $this->stringifyData($data),
                        ],
                    ]
                );

            if (!$response->successful()) {
                Log::warning('FCM non-2xx', [
                    'status' => $response->status(),
                    'body' => substr($response->body(), 0, 200),
                ]);
                return false;
            }

            return true;
        } catch (\Throwable $e) {
            Log::error('FCM send exception', ['error' => $e->getMessage()]);
            return false;
        }
    }

    public function name(): string
    {
        return 'firebase';
    }

    /**
     * Mint an OAuth2 access token from the service-account credentials.
     *
     * Returns null when the service account JSON is missing/malformed or when
     * the OAuth exchange fails — callers treat null as failure, so a broken
     * config surfaces immediately in logs instead of silently dropping pushes.
     */
    private function mintAccessToken(): ?string
    {
        return Cache::remember(
            self::TOKEN_CACHE_KEY,
            self::TOKEN_CACHE_TTL,
            function () {
                $creds = $this->loadCredentials();
                if ($creds === null) {
                    return null;
                }
                return $this->fetchAccessToken($creds);
            }
        );
    }

    /**
     * Load and validate the service-account JSON. Returns null on any
     * malformed shape — we never want to throw from this path because the
     * caller treats failure as "drop this push", not "fail the request".
     *
     * @return array{client_email: string, private_key: string}|null
     */
    private function loadCredentials(): ?array
    {
        if ($this->credentials !== null) {
            return $this->credentials;
        }

        $contents = @file_get_contents($this->credentialsPath);
        if ($contents === false) {
            Log::warning('FCM credentials file unreadable', [
                'path' => $this->credentialsPath,
            ]);
            return null;
        }

        $decoded = json_decode($contents, true);
        if (!is_array($decoded)
            || !isset($decoded['client_email'], $decoded['private_key'])
            || !is_string($decoded['client_email'])
            || !is_string($decoded['private_key'])
        ) {
            Log::warning('FCM credentials JSON missing required fields', [
                'has_client_email' => isset($decoded['client_email']),
                'has_private_key' => isset($decoded['private_key']),
            ]);
            return null;
        }

        $this->credentials = [
            'client_email' => $decoded['client_email'],
            'private_key' => $decoded['private_key'],
        ];
        return $this->credentials;
    }

    /**
     * Build the self-signed RS256 JWT and exchange it at Google's OAuth2
     * token endpoint. Returns the access_token string or null on any error.
     *
     * @param array{client_email: string, private_key: string} $creds
     */
    private function fetchAccessToken(array $creds): ?string
    {
        $now = time();
        try {
            $jwt = JWT::encode(
                [
                    'iss' => $creds['client_email'],
                    'scope' => self::FCM_SCOPE,
                    'aud' => self::OAUTH_TOKEN_URL,
                    'iat' => $now,
                    'exp' => $now + 3600,
                ],
                $creds['private_key'],
                'RS256'
            );
        } catch (\Throwable $e) {
            Log::error('FCM JWT sign failed', ['error' => $e->getMessage()]);
            return null;
        }

        try {
            $response = Http::timeout($this->timeout)
                ->asForm()
                ->post(self::OAUTH_TOKEN_URL, [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $jwt,
                ]);

            if (!$response->successful()) {
                Log::warning('FCM OAuth token exchange non-2xx', [
                    'status' => $response->status(),
                    'body' => substr($response->body(), 0, 200),
                ]);
                return null;
            }

            $payload = $response->json();
            if (!is_array($payload) || !isset($payload['access_token']) || !is_string($payload['access_token'])) {
                Log::warning('FCM OAuth token exchange missing access_token', [
                    'keys' => is_array($payload) ? array_keys($payload) : null,
                ]);
                return null;
            }

            return $payload['access_token'];
        } catch (\Throwable $e) {
            Log::error('FCM OAuth token exchange exception', ['error' => $e->getMessage()]);
            return null;
        }
    }

    private function isConfigured(): bool
    {
        return $this->projectId !== ''
            && $this->credentialsPath !== ''
            && is_file($this->credentialsPath);
    }

    /**
     * FCM data payloads must be string → string. We coerce bool/numeric to
     * their string form so callers can pass arrays with integer ride ids
     * and still hit the wire correctly.
     */
    private function stringifyData(array $data): array
    {
        $out = [];
        foreach ($data as $k => $v) {
            $out[(string) $k] = is_scalar($v) ? (string) $v : json_encode($v);
        }
        return $out;
    }
}
