<?php

namespace App\Http\Controllers\Api\V1;

use App\Constants\ErrorCodes;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\Ride;
use App\Services\LocationService;
use App\Support\ApiResponse;

class PublicTrackController extends Controller
{
    public function track(string $token)
    {
        $ride = Ride::where('track_token', $token)
            ->orWhere('share_token', $token)
            ->with(['driver.driverProfile', 'vehicleType'])
            ->first();

        if (!$ride) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Track link invalid', 404);
        }

        $location = null;
        if ($ride->driver_id) {
            $location = app(LocationService::class)->getDriverLocation($ride->driver_id);
        }

        return ApiResponse::success([
            'ride_id' => $ride->id,
            'status' => $ride->status,
            'sos_active' => $ride->sos_active,
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
            'driver' => $ride->driver ? [
                'name' => $ride->driver->name,
                'plate_no' => $ride->driver->driverProfile?->plate_no,
                'vehicle' => $ride->driver->driverProfile?->vehicle_model,
            ] : null,
            'location' => $location,
            'updated_at' => now()->toIso8601String(),
        ]);
    }
}
