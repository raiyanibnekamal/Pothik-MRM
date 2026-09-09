<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Enums\RideStatus;
use App\Exceptions\ApiException;
use App\Models\Rating;
use App\Models\Ride;
use App\Models\User;
use App\Models\VehicleType;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RideService
{
    public function create(User $passenger, array $data): Ride
    {
        $vehicleType = VehicleType::where('id', $data['vehicle_type_id'])
            ->where('is_active', true)
            ->first();

        if (!$vehicleType) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Vehicle type not found', 404);
        }

        app(LocationService::class)->validateCoordinates($data['pickup_lat'], $data['pickup_lng']);
        app(LocationService::class)->validateCoordinates($data['drop_lat'], $data['drop_lng']);

        if (!$this->isInServiceZone($data['pickup_lat'], $data['pickup_lng'])) {
            throw new ApiException(ErrorCodes::OUT_OF_ZONE, 'এই এলাকায় এখন সার্ভিস নেই।', 422);
        }

        $estimate = app(FareService::class)->estimate(
            $vehicleType,
            $data['pickup_lat'],
            $data['pickup_lng'],
            $data['drop_lat'],
            $data['drop_lng']
        );

        $ride = Ride::create([
            'passenger_id' => $passenger->id,
            'vehicle_type_id' => $vehicleType->id,
            'status' => RideStatus::REQUESTED,
            'payment_method' => $data['payment_method'] ?? 'cash',
            'pickup_lat' => $data['pickup_lat'],
            'pickup_lng' => $data['pickup_lng'],
            'pickup_address' => $data['pickup_address'],
            'drop_lat' => $data['drop_lat'],
            'drop_lng' => $data['drop_lng'],
            'drop_address' => $data['drop_address'],
            'estimated_distance_km' => $estimate['distance_km'],
            'estimated_duration_min' => $estimate['duration_min'],
            'estimated_fare' => $estimate['fare'],
            'share_token' => Str::random(48),
        ]);

        app(DispatchService::class)->startDispatch($ride);

        return $ride->fresh(['vehicleType']);
    }

    public function transition(Ride $ride, string $toStatus, ?User $actor = null, ?string $reason = null): Ride
    {
        if (!RideStatus::canTransition($ride->status, $toStatus)) {
            throw new ApiException(
                ErrorCodes::INVALID_TRANSITION,
                "Cannot transition from {$ride->status} to {$toStatus}",
                409
            );
        }

        $updates = ['status' => $toStatus];

        if ($toStatus === RideStatus::DRIVER_ARRIVED) {
            // no extra fields
        }

        if ($toStatus === RideStatus::IN_PROGRESS) {
            $updates['started_at'] = now();
        }

        if ($toStatus === RideStatus::COMPLETED) {
            $updates['completed_at'] = now();
        }

        if ($toStatus === RideStatus::CANCELLED) {
            $updates['cancelled_at'] = now();
            $updates['cancel_reason'] = $reason;
            $updates['cancelled_by'] = $actor?->id;
        }

        $ride->update($updates);

        return $ride->fresh();
    }

    public function verifyPin(Ride $ride, string $pin, User $driver): Ride
    {
        if ($ride->driver_id !== $driver->id) {
            throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        if ($ride->status !== RideStatus::DRIVER_ARRIVED) {
            throw new ApiException(ErrorCodes::INVALID_TRANSITION, 'PIN only at driver_arrived', 409);
        }

        if ($ride->pin !== $pin) {
            throw new ApiException(ErrorCodes::PIN_MISMATCH, 'PIN mismatch', 422);
        }

        $lock = app(FareService::class)->lockFare(
            $ride->vehicleType,
            (float) $ride->pickup_lat,
            (float) $ride->pickup_lng,
            (float) $ride->drop_lat,
            (float) $ride->drop_lng
        );

        $ride->update([
            'status' => RideStatus::IN_PROGRESS,
            'started_at' => now(),
            'locked_fare' => $lock['locked_fare'],
            'estimated_distance_km' => $lock['distance_km'],
            'estimated_duration_min' => $lock['duration_min'],
            'fare_locked_with_google' => $lock['fare_locked_with_google'],
            'fare_flagged_for_ops' => $lock['fare_flagged_for_ops'],
            'track_token' => $ride->track_token ?? Str::random(48),
        ]);

        return $ride->fresh();
    }

    public function rate(Ride $ride, User $rater, int $score, ?array $tags = null, ?string $comment = null): Rating
    {
        if ($ride->status !== RideStatus::COMPLETED) {
            throw new ApiException(ErrorCodes::INVALID_TRANSITION, 'Ride not completed', 409);
        }

        if ($rater->id !== $ride->passenger_id && $rater->id !== $ride->driver_id) {
            throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        $ratedId = $rater->id === $ride->passenger_id ? $ride->driver_id : $ride->passenger_id;

        if (Rating::where('ride_id', $ride->id)->where('rater_id', $rater->id)->exists()) {
            throw new ApiException(ErrorCodes::ALREADY_RATED, 'Already rated', 409);
        }

        return DB::transaction(function () use ($ride, $rater, $ratedId, $score, $tags, $comment) {
            $rating = Rating::create([
                'ride_id' => $ride->id,
                'rater_id' => $rater->id,
                'rated_id' => $ratedId,
                'score' => $score,
                'tags' => $tags,
                'comment' => $comment,
            ]);

            $rated = User::find($ratedId);
            if ($rated) {
                $newCount = $rated->rating_count + 1;
                $newAvg = (($rated->rating_avg * $rated->rating_count) + $score) / $newCount;
                $rated->update(['rating_avg' => round($newAvg, 2), 'rating_count' => $newCount]);
            }

            return $rating;
        });
    }

    public function formatRide(Ride $ride, bool $includePhone = false): array
    {
        $ride->loadMissing(['passenger', 'driver.driverProfile', 'vehicleType']);

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
            'estimated_fare' => (float) $ride->estimated_fare,
            'locked_fare' => $ride->locked_fare ? (float) $ride->locked_fare : null,
            'final_fare' => $ride->final_fare ? (float) $ride->final_fare : null,
            'pin' => $ride->pin,
            'vehicle_type' => $ride->vehicleType ? [
                'slug' => $ride->vehicleType->slug,
                'name_en' => $ride->vehicleType->name_en,
                'name_bn' => $ride->vehicleType->name_bn,
            ] : null,
            'passenger' => $ride->passenger ? [
                'id' => $ride->passenger->id,
                'name' => $ride->passenger->name,
                'rating' => (float) $ride->passenger->rating_avg,
            ] : null,
            'driver' => null,
            'sos_active' => $ride->sos_active,
            'matched_at' => $ride->matched_at?->toIso8601String(),
            'started_at' => $ride->started_at?->toIso8601String(),
            'completed_at' => $ride->completed_at?->toIso8601String(),
        ];

        if ($ride->driver) {
            $profile = $ride->driver->driverProfile;
            $driverData = [
                'id' => $ride->driver->id,
                'name' => $ride->driver->name,
                'photo_url' => $ride->driver->photo_url,
                'rating' => (float) $ride->driver->rating_avg,
                'rating_count' => $ride->driver->rating_count,
                'is_verified' => $profile?->kyc_status === 'approved',
                'vehicle' => $profile ? [
                    'make' => $profile->vehicle_make,
                    'model' => $profile->vehicle_model,
                    'color' => $profile->vehicle_color,
                    'plate_no' => $profile->plate_no,
                    'photo_url' => $profile->vehicle_photo_url,
                ] : null,
            ];

            if ($includePhone && in_array($ride->status, RideStatus::activeStatuses(), true)) {
                $driverData['phone'] = $ride->driver->phone;
            }

            $data['driver'] = $driverData;
        }

        return $data;
    }

    private function isInServiceZone(float $lat, float $lng): bool
    {
        $zones = \App\Models\ServiceZone::where('is_active', true)->get();
        if ($zones->isEmpty()) {
            return true;
        }

        foreach ($zones as $zone) {
            if ($this->pointInPolygon($lat, $lng, $zone->polygon ?? [])) {
                return true;
            }
        }

        return false;
    }

    private function pointInPolygon(float $lat, float $lng, array $polygon): bool
    {
        if (count($polygon) < 3) {
            return true;
        }

        $inside = false;
        $j = count($polygon) - 1;

        for ($i = 0; $i < count($polygon); $i++) {
            $xi = $polygon[$i]['lat'] ?? $polygon[$i][0] ?? 0;
            $yi = $polygon[$i]['lng'] ?? $polygon[$i][1] ?? 0;
            $xj = $polygon[$j]['lat'] ?? $polygon[$j][0] ?? 0;
            $yj = $polygon[$j]['lng'] ?? $polygon[$j][1] ?? 0;

            if ((($yi > $lng) !== ($yj > $lng))
                && ($lat < ($xj - $xi) * ($lng - $yi) / (($yj - $yi) ?: 1e-10) + $xi)) {
                $inside = !$inside;
            }
            $j = $i;
        }

        return $inside;
    }
}
