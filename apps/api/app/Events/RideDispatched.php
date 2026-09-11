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
        // Must match the driver channel closure in routes/channels.php
        // (`driver.{id}`) AND the driver app's `private-driver.{driverId}`
        // subscription in DriverSocketService. The earlier `user.{id}`
        // target was unreachable — drivers never subscribe to a generic
        // `private-user.{id}` channel, so dispatch offers were silently
        // dropped between the API and the device.
        return [new PrivateChannel('driver.' . $this->driverId)];
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
