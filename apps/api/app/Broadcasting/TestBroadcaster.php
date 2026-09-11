<?php

namespace App\Broadcasting;

use Illuminate\Broadcasting\Broadcasters\Broadcaster;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

/**
 * Phase 0d — TestBroadcaster.
 *
 * Replicates the channel-closure auth check that Pusher/Reverb perform in
 * production, but without any actual socket plumbing. Used by feature tests
 * so we can exercise the closure rules in routes/channels.php without
 * standing up a real Reverb server or stubbing the Pusher SDK.
 *
 * Behaviour mirrors PusherBroadcaster::auth():
 *   1. Resolve the authenticated user from the request (via the route's
 *      auth:api middleware that runs before us).
 *   2. Walk the registered channel closures until one matches the channel.
 *   3. If the closure returns `false` (or no closure matches) respond 403.
 *   4. If the closure returns an array, echo it back verbatim.
 *   5. If the closure returns `true`, respond `{auth: ''}` so the client
 *      knows the request was accepted.
 *
 * Used by tests when BROADCAST_DRIVER=test (see phpunit.xml).
 */
class TestBroadcaster extends Broadcaster
{
    public function auth($request)
    {
        /** @var Request $request */
        $channel = $request->input('channel_name');

        if (! is_string($channel) || $channel === '') {
            throw new AccessDeniedHttpException('Channel name is required.');
        }

        $user = $this->retrieveUser($request, $channel);

        if ($user === null) {
            throw new AccessDeniedHttpException('Unauthenticated.');
        }

        // The Pusher/Reverb protocols both prefix private channels with
        // "private-" before hitting the auth endpoint, but the registered
        // channel patterns in routes/channels.php are bare ("user.{id}").
        // Strip the prefix so the base class's pattern matcher can find
        // the right closure.
        $stripped = preg_replace('/^private-/', '', $channel) ?? $channel;

        // verifyUserCanAccessChannel is protected on the base class — call
        // it via reflection so we don't have to override every layer.
        $reflection = new \ReflectionMethod(Broadcaster::class, 'verifyUserCanAccessChannel');
        $reflection->setAccessible(true);

        $result = $reflection->invoke($this, $request, $stripped);

        if ($result === false || $result === null) {
            throw new AccessDeniedHttpException('Channel access denied.');
        }

        if (is_array($result)) {
            return $result;
        }

        // Closure returned a truthy non-array — return a minimal payload.
        return ['auth' => $this->signChannel($request, $channel)];
    }

    /**
     * Pusher-style auth signature. We use a constant token since the test
     * only needs to assert "did we get an `auth` blob back?" — not whether
     * the signature is cryptographically valid for a real broker.
     */
    private function signChannel(Request $request, string $channel): string
    {
        return sprintf(
            '%s:%s',
            $request->input('socket_id', '0.0'),
            hash('sha256', $channel)
        );
    }

    public function validAuthenticationResponse($request, $result)
    {
        // $result is what the closure returned: either an array (echoed back
        // verbatim) or `true` (synthesise a minimal pusher-style auth blob).
        if (is_array($result)) {
            return $result;
        }

        /** @var Request $request */
        $channel = (string) $request->input('channel_name', '');
        $stripped = preg_replace('/^private-/', '', $channel) ?? $channel;

        return ['auth' => $this->signChannel($request, $stripped)];
    }

    public function broadcast(array $channels, $event, array $payload = [])
    {
        // No-op — we don't actually deliver events in tests.
    }
}
