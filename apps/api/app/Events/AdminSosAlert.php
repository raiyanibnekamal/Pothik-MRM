<?php

namespace App\Events;

use App\Models\SosAlert;
use Illuminate\Broadcasting\InteractsWithSockets;
use App\Constants\SocketEvents;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AdminSosAlert implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public SosAlert $alert) {}

    public function broadcastOn(): array
    {
        // Channel must match the closure in routes/channels.php
        // (`admin.sos`) AND the admin panel's `private-admin.sos`
        // subscription. The earlier `admin.ops` target was unreachable
        // for the SOS event — admin panel subscribes to admin.sos
        // specifically for low-volume SOS bursts, so alerts were
        // dropped between the API and the panel.
        return [new PrivateChannel('admin.sos')];
    }

    public function broadcastAs(): string
    {
        // Single source of truth: SocketEvents::ADMIN_SOS_ALERT.
        // Hardcoding the string here was a refactor risk — if the
        // admin panel ever renamed the event name, the channel auth
        // test would still pass while subscribers went silent.
        return SocketEvents::ADMIN_SOS_ALERT;
    }

    public function broadcastWith(): array
    {
        return [
            'alert_id' => $this->alert->id,
            'user_id' => $this->alert->user_id,
            'ride_id' => $this->alert->ride_id,
            'lat' => $this->alert->lat,
            'lng' => $this->alert->lng,
            'trigger_type' => $this->alert->trigger_type,
            'created_at' => $this->alert->created_at?->toIso8601String(),
        ];
    }
}
