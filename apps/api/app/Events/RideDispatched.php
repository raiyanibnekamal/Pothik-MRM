<?php

namespace App\Events;

use App\Models\Ride;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RideDispatched implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Ride $ride,
        public string $driverId,
        public array $payload
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('user.' . $this->driverId)];
    }

    public function broadcastAs(): string
    {
        return 'server:ride:dispatched';
    }

    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
