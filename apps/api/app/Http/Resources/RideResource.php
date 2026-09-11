<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Ride shape returned via API. Use for passenger/driver/admin ride detail
 * payloads. Optional `includeSensitive` flag drives whether PIN/share_token/
 * track_token are exposed (only when status is active and the caller
 * is the assigned driver/passenger — controllers decide).
 */
class RideResource extends JsonResource
{
    private bool $includeSensitive = false;

    public function withSensitive(bool $include = true): self
    {
        $clone = clone $this;
        $clone->includeSensitive = $include;

        return $clone;
    }

    // NOTE: parent `JsonResource::toArray($request)` is untyped in
    // this Laravel version; narrowing either the parameter or the
    // return type triggers an LSP fatal at autoload time.
    public function toArray($request)
    {
        $ride = $this->resource;
        $vehicleType = $ride->vehicleType ?? null;

        $data = [
            'id' => $ride->id,
            'status' => $ride->status,
            'payment_method' => $ride->payment_method,
            'pickup' => [
                'lat' => (float) $ride->pickup_lat,
                'lng' => (float) $ride->pickup_lng,
                'address' => $ride->pickup_address,
            ],
            'drop' => [
                'lat' => (float) $ride->drop_lat,
                'lng' => (float) $ride->drop_lng,
                'address' => $ride->drop_address,
            ],
            'distance_km' => $ride->estimated_distance_km
                ? (float) $ride->estimated_distance_km
                : null,
            'duration_min' => $ride->estimated_duration_min
                ? (int) $ride->estimated_duration_min
                : null,
            'estimated_fare' => (float) $ride->estimated_fare,
            'locked_fare' => $ride->locked_fare ? (float) $ride->locked_fare : null,
            'final_fare' => $ride->final_fare ? (float) $ride->final_fare : null,
            'fare_flagged_for_ops' => (bool) $ride->fare_flagged_for_ops,
            'vehicle_type' => $vehicleType ? [
                'id' => $vehicleType->id,
                'slug' => $vehicleType->slug,
                'name_en' => $vehicleType->name_en,
                'name_bn' => $vehicleType->name_bn,
            ] : null,
            'passenger' => $ride->passenger
                ? (new PublicUserResource($ride->passenger))->toArray($request)
                : null,
            'driver' => $ride->driver
                ? (new PublicUserResource($ride->driver))->toArray($request)
                : null,
            'sos_active' => (bool) $ride->sos_active,
            'matched_at' => $ride->matched_at?->toIso8601String(),
            'started_at' => $ride->started_at?->toIso8601String(),
            'completed_at' => $ride->completed_at?->toIso8601String(),
            'cancelled_at' => $ride->cancelled_at?->toIso8601String(),
            'cancel_reason' => $ride->cancel_reason,
            'cancelled_by' => $ride->cancelled_by,
        ];

        if ($this->includeSensitive) {
            $data['pin'] = $ride->pin;
            $data['share_token'] = $ride->share_token;
            $data['track_token'] = $ride->track_token;
        }

        return $data;
    }
}
