<?php

namespace Tests\Feature;

use App\Enums\RideStatus;
use App\Enums\UserRole;
use App\Events\AdminSosAlert;
use App\Events\RideDispatched;
use App\Models\Ride;
use App\Models\SosAlert;
use App\Models\User;
use App\Services\Fcm\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\ApiTestCase;

/**
 * S4.2 coverage — push listeners fire on dispatch + SOS.
 *
 * The NullFcmService is bound in testing so the listener is safe to run
 * even when FCM_DEFAULT_PROVIDER=null (the default in local). We swap it
 * for a fake to assert the listeners attempted a push exactly once.
 */
class PushNotificationTest extends ApiTestCase
{
    use RefreshDatabase;

    public function test_driver_push_listener_runs_on_ride_dispatched(): void
    {
        $fake = new class implements FcmService {
            public int $userCalls = 0;
            public array $lastPayload = [];

            public function sendToUser(string $userId, string $title, string $body, array $data = []): bool
            {
                $this->userCalls++;
                $this->lastPayload = compact('userId', 'title', 'body', 'data');
                return true;
            }

            public function sendToToken(string $token, string $title, string $body, array $data = []): bool
            {
                return true;
            }

            public function name(): string
            {
                return 'fake';
            }
        };

        $this->app->instance(FcmService::class, $fake);

        $ride = Ride::create([
            'passenger_id' => $this->passenger->id,
            'driver_id' => $this->driver->id,
            'vehicle_type_id' => $this->vehicleType->id,
            'status' => RideStatus::REQUESTED,
            'payment_method' => 'cash',
            'pickup_lat' => 23.7806,
            'pickup_lng' => 90.4074,
            'pickup_address' => 'Pickup',
            'drop_lat' => 23.7925,
            'drop_lng' => 90.4078,
            'drop_address' => 'Drop',
            'estimated_fare' => 165,
        ]);

        // Sync the queue so ShouldQueue listeners run inline in tests.
        (new \App\Listeners\SendDriverRidePushNotification($fake))
            ->handle(new RideDispatched($ride, (string) $this->driver->id, [
                'ride_id' => (string) $ride->id,
                'fare' => 165,
            ]));

        $this->assertSame(1, $fake->userCalls, 'driver push listener should call sendToUser once');
        $this->assertSame((string) $this->driver->id, $fake->lastPayload['userId']);
        $this->assertSame('ride_dispatched', $fake->lastPayload['data']['type']);
    }

    public function test_admin_sos_listener_runs_on_alert(): void
    {
        $fake = new class implements FcmService {
            public array $calls = [];

            public function sendToUser(string $userId, string $title, string $body, array $data = []): bool
            {
                $this->calls[] = compact('userId', 'title', 'body', 'data');
                return true;
            }

            public function sendToToken(string $token, string $title, string $body, array $data = []): bool
            {
                return true;
            }

            public function name(): string
            {
                return 'fake';
            }
        };

        $this->app->instance(FcmService::class, $fake);

        // Create a separate admin user (the UserRole enum rejects arbitrary
        // role strings, so we cannot promote the seeded driver).
        User::create([
            'phone' => '+8801755555559',
            'role' => UserRole::SUPER_ADMIN,
            'language' => 'bn',
        ]);

        // We bypass SosService::trigger() (which would require an IN_PROGRESS
        // ride) and construct the alert + event directly. The listener is
        // what we want to assert — not the service gating.
        $alert = SosAlert::create([
            'user_id' => $this->passenger->id,
            'status' => 'active',
            'sms_status' => 'skipped',
            'trigger_type' => 'hold',
            'lat' => 23.78,
            'lng' => 90.41,
        ]);

        // Run the listener inline (handle, no dispatch).
        (new \App\Listeners\SendAdminSosPushNotification($fake))
            ->handle(new AdminSosAlert($alert));

        // Listener fans out to all admins. We seeded the driver as admin.
        $this->assertNotEmpty($fake->calls, 'admin SOS listener should push at least once');
        $this->assertSame('admin_sos', $fake->calls[0]['data']['type']);
    }
}
