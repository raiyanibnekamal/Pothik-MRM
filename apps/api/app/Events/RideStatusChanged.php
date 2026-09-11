<?php

namespace App\Events;

use App\Constants\SocketEvents;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Server → passenger + driver fan-out for any ride state transition.
 *
 * Replaces ad-hoc broadcasts that used to live in DispatchService.accept()
 * and RideService.transition(). One event, two channels, single payload
 * shape — the broker decides whether to fan out separately or to share.
 *
 * Channels are derived from the ride's passenger_id + driver_id at broadcast
 * time; driver_id may be null on the very first REQUESTED → NO_DRIVER event
 * in which case we drop the driver channel entirely rather than broadcasting
 * on private-driver.null (which would 403 the auth lookup).
 */
class RideStatusChanged implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $rideId,
        public string $passengerId,
        public ?string $driverId,
        public string $fromStatus,
        public string $toStatus,
        public string $eventName,
        public array $extra = []
    ) {}

    public function broadcastOn(): array
    {
        $channels = [new PrivateChannel('passenger.' . $this->passengerId)];

        if ($this->driverId !== null && $this->driverId !== '') {
            $channels[] = new PrivateChannel('driver.' . $this->driverId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return $this->eventName;
    }

    public function broadcastWith(): array
    {
        return array_merge([
            'event' => $this->eventName,
            'ride_id' => $this->rideId,
            'from_status' => $this->fromStatus,
            'to_status' => $this->toStatus,
        ], $this->extra);
    }
}
