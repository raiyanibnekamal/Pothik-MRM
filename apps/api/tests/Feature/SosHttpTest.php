<?php

namespace Tests\Feature;

use App\Enums\RideStatus;
use App\Events\AdminSosAlert;
use App\Models\EmergencyContact;
use App\Models\Ride;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\Feature\ApiTestCase;

/**
 * S5.1 — SOS HTTP regression. Verifies that the trigger / cancel / resolve
 * round-trip flows through the JSON shape the mobile apps expect.
 *
 * Gating note: SosService::assertGating throws when a passenger has no
 * IN_PROGRESS ride, so each test seeds one via seedInProgressRide()
 * before hitting the trigger endpoint.
 */
class SosHttpTest extends ApiTestCase
{
    use RefreshDatabase;

    private function seedInProgressRide(string $payment = 'cash'): Ride
    {
        return Ride::create([
            'passenger_id' => $this->passenger->id,
            'driver_id' => $this->driver->id,
            'vehicle_type_id' => $this->vehicleType->id,
            'status' => RideStatus::IN_PROGRESS,
            'payment_method' => $payment,
            'pin' => '4821',
            'pickup_lat' => 23.7806,
            'pickup_lng' => 90.4074,
            'pickup_address' => 'Pickup',
            'drop_lat' => 23.7925,
            'drop_lng' => 90.4078,
            'drop_address' => 'Drop',
            'started_at' => now()->subMinute(),
        ]);
    }

    public function test_passenger_can_trigger_sos_and_admin_sos_event_fires(): void
    {
        $ride = $this->seedInProgressRide();

        Event::fake([AdminSosAlert::class]);

        $payload = $this->postJson('/api/v1/sos/trigger', [
            'ride_id' => $ride->id,
            'lat' => 23.7806,
            'lng' => 90.4074,
            'trigger_type' => 'shake',
        ], $this->authHeaders($this->passenger));

        $payload->assertStatus(201);
        $payload->assertJsonPath('data.user_id', $this->passenger->id);
        $payload->assertJsonPath('data.trigger_type', 'shake');
        $payload->assertJsonPath('data.status', 'active');

        Event::assertDispatched(AdminSosAlert::class);
    }

    public function test_passenger_can_cancel_their_own_sos(): void
    {
        $ride = $this->seedInProgressRide();

        $created = $this->postJson('/api/v1/sos/trigger', [
            'ride_id' => $ride->id,
            'lat' => 23.78,
            'lng' => 90.41,
            'trigger_type' => 'shake',
        ], $this->authHeaders($this->passenger));

        $id = $created->json('data.id');

        $this->postJson("/api/v1/sos/{$id}/cancel", [], $this->authHeaders($this->passenger))
            ->assertStatus(200)
            ->assertJsonPath('data.status', 'cancelled');
    }

    public function test_resolve_endpoint_rejects_non_admin_users(): void
    {
        $ride = $this->seedInProgressRide();

        $created = $this->postJson('/api/v1/sos/trigger', [
            'ride_id' => $ride->id,
            'lat' => 23.78,
            'lng' => 90.41,
            'trigger_type' => 'hold',
        ], $this->authHeaders($this->passenger));

        $id = $created->json('data.id');

        // Passenger cannot resolve their own SOS — admin role only.
        $this->postJson("/api/v1/admin/sos/{$id}/resolve", [], $this->authHeaders($this->passenger))
            ->assertStatus(403);
    }

    public function test_active_sms_status_reports_skipped_when_no_contacts(): void
    {
        $ride = $this->seedInProgressRide();

        $created = $this->postJson('/api/v1/sos/trigger', [
            'ride_id' => $ride->id,
            'lat' => 23.78,
            'lng' => 90.41,
            'trigger_type' => 'shake',
        ], $this->authHeaders($this->passenger));

        $created->assertJsonPath('data.sms_status', 'skipped');
    }

    public function test_active_sms_status_reports_sent_when_contacts_receivable(): void
    {
        $ride = $this->seedInProgressRide();

        EmergencyContact::create([
            'user_id' => $this->passenger->id,
            'name' => 'Family',
            'phone' => '+8801711111112',
            'relation' => 'spouse',
        ]);

        // Force the SmsService to a fake that always succeeds.
        $this->app->instance(
            \App\Services\SmsService::class,
            new class {
                public function send(string $phone, string $message): bool { return true; }
                public function sendSos(string $phone, string $message): bool { return true; }
            }
        );

        $this->postJson('/api/v1/sos/trigger', [
            'ride_id' => $ride->id,
            'lat' => 23.78,
            'lng' => 90.41,
            'trigger_type' => 'hold',
        ], $this->authHeaders($this->passenger))
            ->assertStatus(201)
            ->assertJsonPath('data.sms_status', 'sent');
    }
}
