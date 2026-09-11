<?php

namespace App\Providers;

use App\Events\AdminSosAlert;
use App\Events\RideDispatched;
use App\Listeners\SendAdminSosPushNotification;
use App\Listeners\SendDriverRidePushNotification;
use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Listeners\SendEmailVerificationNotification;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Event;

class EventServiceProvider extends ServiceProvider
{
    /**
     * The event listener mappings for the application.
     *
     * @var array<class-string, array<int, class-string>>
     */
    protected $listen = [
        Registered::class => [
            SendEmailVerificationNotification::class,
        ],

        // S2.4 / S4.2 — driver push on dispatched ride.
        // Queue-safe; the NullFcmService logs in local/testing and the
        // socket is the source of truth, so dispatch latency is unaffected.
        RideDispatched::class => [
            SendDriverRidePushNotification::class,
        ],

        // S4.2 — admin push when SOS is triggered.
        AdminSosAlert::class => [
            SendAdminSosPushNotification::class,
        ],
    ];

    /**
     * Register any events for your application.
     *
     * @return void
     */
    public function boot()
    {
        //
    }
}
