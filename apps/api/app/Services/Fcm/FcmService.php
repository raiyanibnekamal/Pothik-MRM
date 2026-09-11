<?php

namespace App\Services\Fcm;

/**
 * Push-notification gateway contract.
 *
 * Concrete implementations deliver Firebase Cloud Messaging payloads to one
 * or more device tokens. The NullFcmService implementation logs and returns
 * true so it can be the default in local / testing without contacting Google.
 *
 * Returns true if the gateway acknowledged the send (single batch), false on
 * any failure mode (network, 4xx/5xx, missing config, no tokens).
 */
interface FcmService
{
    /**
     * Send a notification to every device registered for a user.
     *
     * @param  string  $userId  Local user id (looked up against device_tokens)
     * @param  string  $title   Notification title (BN/EN — mobile picks at display time)
     * @param  string  $body    Notification body
     * @param  array   $data    Extra payload (e.g. ['ride_id' => '...', 'type' => 'ride_assigned'])
     * @return bool             true if the gateway accepted the batch
     */
    public function sendToUser(string $userId, string $title, string $body, array $data = []): bool;

    /**
     * Send a notification directly to a known FCM device token (used for
     * testing/admin tooling).
     *
     * @param  string  $token   FCM registration token
     * @param  string  $title
     * @param  string  $body
     * @param  array   $data
     * @return bool
     */
    public function sendToToken(string $token, string $title, string $body, array $data = []): bool;

    /**
     * Stable identifier for this driver — used by tests to verify which
     * path executed.
     */
    public function name(): string;
}
