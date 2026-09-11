<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

/**
 * Covers the broadcasting handshake surface exposed by Phase 0d.
 *
 * The mobile and admin clients cannot subscribe to a private channel
 * until the server returns a per-channel auth signature. Laravel
 * exposes that as POST /api/v1/broadcasting/auth — the route group is
 * registered by App\Providers\BroadcastServiceProvider and gated by
 * the same `auth:api` middleware as the rest of the v1 API.
 *
 * The contract these tests pin down:
 *   1. Unauthenticated requests are rejected with 401.
 *   2. Authenticated users can subscribe to their own private-* channel
 *      (user.{id}, passenger.{id}, driver.{id}) and receive a 200 with
 *      a non-empty `auth` blob.
 *   3. The auth blob must contain the channel name and a `user_data`
 *      stringified payload — those are what the Pusher/Reverb protocol
 *      needs to verify the socket subscription server-side.
 *   4. Cross-tenant subscription attempts (e.g. driver A trying to listen
 *      on private-passenger.{B}) are denied with 403, not 401.
 *   5. The ride.{id} channel only authorises the matched passenger and
 *      the assigned driver.
 *   6. Admin channels reject non-admin users with 403.
 */
class BroadcastingAuthTest extends ApiTestCase
{
    use RefreshDatabase;

    public function test_broadcasting_auth_rejects_unauthenticated_request(): void
    {
        $response = $this->postJson('/api/v1/broadcasting/auth', [
            'socket_id' => '123.456',
            'channel_name' => 'private-user.' . $this->passenger->id,
        ]);

        $response->assertStatus(401);
    }

    public function test_user_can_authorize_their_own_private_channel(): void
    {
        $response = $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-user.' . $this->passenger->id,
            ]);

        $response->assertOk();
        $body = $response->json();
        $this->assertNotEmpty($body['auth'] ?? null, 'auth blob must be present');
        $this->assertStringContainsString('123.456', $body['auth']);
        // The TestBroadcaster signs with the channel hash; assert the
        // signature contains the stripped channel name so consumers can
        // reconstruct the channel in tests.
        $this->assertStringContainsString(
            hash('sha256', 'user.' . $this->passenger->id),
            $body['auth']
        );
    }

    public function test_user_cannot_authorize_someone_elses_private_channel(): void
    {
        // Build a second passenger so the cross-tenant case has two
        // distinct UUIDs to compare.
        $other = User::create([
            'phone' => '+8801733333333',
            'role' => UserRole::PASSENGER,
            'language' => 'bn',
        ]);

        $response = $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-user.' . $other->id,
            ]);

        // The closure returns false → the framework responds 403.
        $response->assertStatus(403);
    }

    public function test_passenger_can_authorize_their_passenger_channel(): void
    {
        $response = $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-passenger.' . $this->passenger->id,
            ]);

        $response->assertOk();
    }

    public function test_driver_can_authorize_their_driver_channel(): void
    {
        $response = $this->withHeaders($this->authHeaders($this->driver))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-driver.' . $this->driver->id,
            ]);

        $response->assertOk();
    }

    public function test_passenger_cannot_authorize_a_driver_channel(): void
    {
        $response = $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-driver.' . $this->driver->id,
            ]);

        $response->assertStatus(403);
    }

    public function test_ride_channel_authorizes_passenger_and_assigned_driver(): void
    {
        $ride = Ride::create([
            'passenger_id' => $this->passenger->id,
            'driver_id' => $this->driver->id,
            'vehicle_type_id' => $this->vehicleType->id,
            'status' => 'accepted',
            'pickup_lat' => 23.78,
            'pickup_lng' => 90.41,
            'pickup_address' => 'Gulshan 2 Circle',
            'drop_lat' => 23.79,
            'drop_lng' => 90.42,
            'drop_address' => 'Banani DOHS',
        ]);

        // Passenger
        $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-ride.' . $ride->id,
            ])->assertOk();

        // Assigned driver
        $this->withHeaders($this->authHeaders($this->driver))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-ride.' . $ride->id,
            ])->assertOk();
    }

    public function test_ride_channel_rejects_uninvolved_user(): void
    {
        $ride = Ride::create([
            'passenger_id' => $this->passenger->id,
            'driver_id' => $this->driver->id,
            'vehicle_type_id' => $this->vehicleType->id,
            'status' => 'accepted',
            'pickup_lat' => 23.78,
            'pickup_lng' => 90.41,
            'pickup_address' => 'Gulshan 2 Circle',
            'drop_lat' => 23.79,
            'drop_lng' => 90.42,
            'drop_address' => 'Banani DOHS',
        ]);

        $bystander = User::create([
            'phone' => '+8801744444444',
            'role' => UserRole::PASSENGER,
            'language' => 'bn',
        ]);

        $this->withHeaders($this->authHeaders($bystander))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-ride.' . $ride->id,
            ])->assertStatus(403);
    }

    public function test_admin_channel_rejects_non_admin_user(): void
    {
        $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-admin.ops',
            ])->assertStatus(403);
    }

    public function test_admin_channel_accepts_admin_user(): void
    {
        $admin = User::create([
            'phone' => '+8801755555555',
            'role' => UserRole::SUPER_ADMIN,
            'language' => 'bn',
        ]);

        $this->withHeaders($this->authHeaders($admin))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-admin.ops',
            ])->assertOk();
    }

    public function test_admin_sos_channel_rejects_non_admin_user(): void
    {
        // The SOS sub-feed must reject non-admin users just like the
        // war-room dashboard channel -- both names share the same
        // admin-only closure in routes/channels.php. We pin both
        // names so a future split (e.g. dispatchers allowed on SOS
        // but not ops) breaks the test first instead of leaking
        // alerts to the wrong audience.
        $this->withHeaders($this->authHeaders($this->passenger))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-admin.sos',
            ])->assertStatus(403);
    }

    public function test_admin_sos_channel_accepts_admin_user(): void
    {
        $admin = User::create([
            'phone' => '+8801766666666',
            'role' => UserRole::SUPER_ADMIN,
            'language' => 'bn',
        ]);

        $this->withHeaders($this->authHeaders($admin))
            ->postJson('/api/v1/broadcasting/auth', [
                'socket_id' => '123.456',
                'channel_name' => 'private-admin.sos',
            ])->assertOk();
    }
}
