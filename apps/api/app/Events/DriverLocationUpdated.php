<?php

namespace App\Events;

use App\Constants\SocketEvents;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Server → passenger private-channel stream.
 *
 * Fired by LocationService::updateDriverLocation() whenever a driver pings
 * their location while on an active ride. Only the matched passenger's
 * channel is authorized (see routes/channels.php passenger.{id}).
 *
 * High-frequency event (driver pings every 3-5s while moving). Marked
 * ShouldBroadcast + queued (via SerializesModels) so a slow websocket
 * broker doesn't block the HTTP response. The "log" broadcaster used in
 * development will skip the queue and write straight to laravel.log.
 */
class DriverLocationUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $rideId,
        public string $passengerId,
        public string $driverId,
        public float $lat,
        public float $lng,
        public ?float $speedKmh,
        public ?float $bearingDeg,
        public string $updatedAt
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('passenger.' . $this->passengerId)];
    }

    public function broadcastAs(): string
    {
        return SocketEvents::SERVER_DRIVER_LOCATION;
    }

    public function broadcastWith(): array
    {
        return [
            'event' => SocketEvents::SERVER_DRIVER_LOCATION,
            'ride_id' => $this->rideId,
            'driver_id' => $this->driverId,
            'lat' => $this->lat,
            'lng' => $this->lng,
            'speed_kmh' => $this->speedKmh,
            'bearing_deg' => $this->bearingDeg,
            'updated_at' => $this->updatedAt,
        ];
    }
}
