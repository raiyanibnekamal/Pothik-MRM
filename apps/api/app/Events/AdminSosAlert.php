<?php

namespace App\Events;

use App\Models\SosAlert;
use Illuminate\Broadcasting\InteractsWithSockets;
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
        return [new PrivateChannel('admin.ops')];
    }

    public function broadcastAs(): string
    {
        return 'admin:sos:alert';
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
