<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Enums\UserRole;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;

/**
 * Channel authorization is the most security-sensitive piece of the
 * realtime layer: a leaked channel means a passenger can listen in on
 * another passenger live driver location. These tests pin the
 * authorization closures in routes/channels.php, so a future refactor
 * that loosens the rules fails loudly here.
 *
 * Strategy: re-execute routes/channels.php inside a closure that traps
 * each Broadcast::channel($pattern, $closure) call into a local map.
 * Then invoke each captured closure directly with a fake $user, which
 * mirrors exactly what the server does when a client subscribes.
 */
class BroadcastChannelsTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, \Closure> */
    private array $channels = [];

    protected function setUp(): void
    {
        parent::setUp();

        $trap = $this;
        \Illuminate\Support\Facades\Broadcast::shouldReceive('channel')
            ->andReturnUsing(function (string $pattern, $closure) use ($trap) {
                $trap->captureChannel($pattern, \Closure::fromCallable($closure));
            });

        require base_path('routes/channels.php');
    }

    public function captureChannel(string $pattern, \Closure $closure): void
    {
        $this->channels[$pattern] = $closure;
    }

    public function test_user_channel_authorizes_matching_id_only(): void
    {
        $closure = $this->channels['user.{id}'];

        $self = $this->userWith('pass-1', UserRole::PASSENGER);
        $other = $this->userWith('pass-2', UserRole::PASSENGER);

        $this->assertTrue((bool) $closure($self, 'pass-1'));
        $this->assertFalse((bool) $closure($other, 'pass-1'));
        $this->assertFalse((bool) $closure($self, 'pass-2'));
    }

    public function test_passenger_channel_only_authorizes_self(): void
    {
        $closure = $this->channels['passenger.{id}'];

        $self = $this->userWith('pass-1', UserRole::PASSENGER);
        $other = $this->userWith('pass-2', UserRole::PASSENGER);

        $this->assertTrue((bool) $closure($self, 'pass-1'));
        $this->assertFalse((bool) $closure($other, 'pass-1'));
    }

    public function test_driver_channel_only_authorizes_self(): void
    {
        $closure = $this->channels['driver.{id}'];

        $self = $this->userWith('drv-1', UserRole::DRIVER);
        $other = $this->userWith('drv-2', UserRole::DRIVER);

        $this->assertTrue((bool) $closure($self, 'drv-1'));
        $this->assertFalse((bool) $closure($other, 'drv-1'));
    }

    public function test_ride_channel_authorizes_passenger_and_assigned_driver(): void
    {
        $closure = $this->channels['ride.{id}'];

        $passenger = $this->userWith('pass-1', UserRole::PASSENGER);
        $assignedDriver = $this->userWith('drv-1', UserRole::DRIVER);
        $unrelatedDriver = $this->userWith('drv-2', UserRole::DRIVER);

        // The ride.{id} channel closure hits the rides table; RefreshDatabase
        // has migrated the schema, so we seed real rows to satisfy the
        // closure's exists() check, then exercise the auth predicate in
        // isolation. The bundled User factory assumes email_verified_at which
        // isn't part of this schema, so we instantiate User models directly.
        $passengerUser = new \App\Models\User();
        $passengerUser->id = (string) \Illuminate\Support\Str::uuid();
        $passengerUser->name = 'Test Passenger';
        $passengerUser->phone = '+8801700000001';
        $passengerUser->role = 'passenger';
        $passengerUser->password = bcrypt('x');
        $passengerUser->save();

        $assignedDriverUser = new \App\Models\User();
        $assignedDriverUser->id = (string) \Illuminate\Support\Str::uuid();
        $assignedDriverUser->name = 'Test Driver';
        $assignedDriverUser->phone = '+8801700000002';
        $assignedDriverUser->role = 'driver';
        $assignedDriverUser->password = bcrypt('x');
        $assignedDriverUser->save();

        $vehicleType = \App\Models\VehicleType::create([
            'slug' => 'car',
            'name_en' => 'Car',
            'name_bn' => 'কার',
            'seats' => 4,
            'base_fare' => 50,
            'per_km_rate' => 18,
            'per_min_rate' => 2,
            'min_fare' => 60,
            'is_active' => true,
        ]);

        $ride = \App\Models\Ride::create([
            'passenger_id' => $passengerUser->id,
            'driver_id' => $assignedDriverUser->id,
            'vehicle_type_id' => $vehicleType->id,
            'pickup_lat' => 23.78,
            'pickup_lng' => 90.40,
            'pickup_address' => 'Banani',
            'drop_lat' => 23.79,
            'drop_lng' => 90.41,
            'drop_address' => 'Gulshan',
            'status' => 'requested',
        ]);

        // Realign the fake $user objects with the persisted UUIDs so the
        // closure's $user->id === rides.passenger_id / driver_id compare
        // resolves against actual DB values.
        $passenger->id = $passengerUser->id;
        $assignedDriver->id = $assignedDriverUser->id;

        $this->assertTrue((bool) $closure($passenger, $ride->id));
        $this->assertTrue((bool) $closure($assignedDriver, $ride->id));
        $this->assertFalse((bool) $closure($unrelatedDriver, $ride->id));
    }

    public function test_admin_ops_channel_authorizes_only_admins(): void
    {
        $closure = $this->channels['admin.ops'];

        $superAdmin = $this->userWith('admin-1', UserRole::SUPER_ADMIN);
        $financeAdmin = $this->userWith('admin-2', UserRole::SUB_ADMIN_FINANCE);
        $supportAgent = $this->userWith('admin-3', UserRole::SUPPORT_AGENT);
        $dispatchAdmin = $this->userWith('admin-4', UserRole::SUB_ADMIN_DISPATCH);
        $supportAdmin = $this->userWith('admin-5', UserRole::SUB_ADMIN_SUPPORT);
        $passenger = $this->userWith('pass-1', UserRole::PASSENGER);
        $driver = $this->userWith('drv-1', UserRole::DRIVER);

        $this->assertTrue((bool) $closure($superAdmin));
        $this->assertTrue((bool) $closure($financeAdmin));
        $this->assertTrue((bool) $closure($supportAgent));
        $this->assertTrue((bool) $closure($dispatchAdmin));
        $this->assertTrue((bool) $closure($supportAdmin));
        $this->assertFalse((bool) $closure($passenger));
        $this->assertFalse((bool) $closure($driver));
    }

    public function test_admin_sos_channel_authorizes_only_admins(): void
    {
        $closure = $this->channels['admin.sos'];

        $dispatchAdmin = $this->userWith('admin-1', UserRole::SUB_ADMIN_DISPATCH);
        $superAdmin = $this->userWith('admin-2', UserRole::SUPER_ADMIN);
        $passenger = $this->userWith('pass-1', UserRole::PASSENGER);
        $driver = $this->userWith('drv-1', UserRole::DRIVER);

        $this->assertTrue((bool) $closure($dispatchAdmin));
        $this->assertTrue((bool) $closure($superAdmin));
        $this->assertFalse((bool) $closure($passenger));
        $this->assertFalse((bool) $closure($driver));
    }

    private function userWith(string $id, string $role): User
    {
        $user = new User();
        $user->id = $id;
        $user->role = $role;

        return $user;
    }
}
