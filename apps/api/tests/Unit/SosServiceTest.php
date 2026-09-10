<?php

namespace Tests\Unit;

use App\Models\EmergencyContact;
use App\Models\SosAlert;
use App\Models\User;
use App\Services\SmsService;
use App\Services\SosService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class SosServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Mockery::close();
        parent::tearDown();
    }

    public function test_notify_guardians_sets_sent_when_all_sms_succeed(): void
    {
        $user = $this->createUser();
        EmergencyContact::create([
            'user_id' => $user->id,
            'name' => 'Guardian 1',
            'phone' => '+8801711000002',
        ]);
        EmergencyContact::create([
            'user_id' => $user->id,
            'name' => 'Guardian 2',
            'phone' => '+8801711000003',
        ]);
        $alert = $this->createAlert($user);

        $sms = Mockery::mock(SmsService::class);
        $sms->shouldReceive('sendSos')->twice()->andReturn(true);
        $this->app->instance(SmsService::class, $sms);

        $this->invokeNotifyGuardians(new SosService(), $user, $alert);

        $this->assertSame('sent', $alert->fresh()->sms_status);
    }

    public function test_notify_guardians_sets_failed_when_any_sms_fails(): void
    {
        $user = $this->createUser();
        EmergencyContact::create([
            'user_id' => $user->id,
            'name' => 'Guardian 1',
            'phone' => '+8801711000002',
        ]);
        EmergencyContact::create([
            'user_id' => $user->id,
            'name' => 'Guardian 2',
            'phone' => '+8801711000003',
        ]);
        $alert = $this->createAlert($user);

        $sms = Mockery::mock(SmsService::class);
        $sms->shouldReceive('sendSos')->once()->andReturn(true);
        $sms->shouldReceive('sendSos')->once()->andReturn(false);
        $this->app->instance(SmsService::class, $sms);

        $this->invokeNotifyGuardians(new SosService(), $user, $alert);

        $this->assertSame('failed', $alert->fresh()->sms_status);
    }

    public function test_notify_guardians_sets_skipped_when_no_contacts(): void
    {
        $user = $this->createUser();
        $alert = $this->createAlert($user);

        $sms = Mockery::mock(SmsService::class);
        $sms->shouldNotReceive('sendSos');
        $this->app->instance(SmsService::class, $sms);

        $this->invokeNotifyGuardians(new SosService(), $user, $alert);

        $this->assertSame('skipped', $alert->fresh()->sms_status);
    }

    private function createUser(): User
    {
        return User::create([
            'phone' => '+8801711' . random_int(100000, 999999),
            'name' => 'Test User',
            'role' => 'passenger',
        ]);
    }

    private function createAlert(User $user): SosAlert
    {
        return SosAlert::create([
            'user_id' => $user->id,
            'status' => 'active',
            'sms_status' => 'pending',
            'trigger_type' => 'hold',
            'lat' => 23.79,
            'lng' => 90.41,
        ]);
    }

    private function invokeNotifyGuardians(SosService $service, User $user, SosAlert $alert): void
    {
        $method = new \ReflectionMethod(SosService::class, 'notifyGuardians');
        $method->setAccessible(true);
        $method->invoke($service, $user, $alert, null);
    }
}
