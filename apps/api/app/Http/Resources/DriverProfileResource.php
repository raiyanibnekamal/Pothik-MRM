<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Driver onboarding / KYC profile shape. Strips NID and exact DOB
 * (PII) and only surfaces them in admin contexts. DOB is included
 * age-derived, not as raw PII.
 */
class DriverProfileResource extends JsonResource
{
    // NOTE: parent `JsonResource::toArray($request)` is untyped in
    // this Laravel version; narrowing either the parameter or the
    // return type triggers an LSP fatal at autoload time.
    public function toArray($request)
    {
        $profile = $this->resource;

        return [
            'id' => $profile->id,
            'user_id' => $profile->user_id,
            'vehicle_type_id' => $profile->vehicle_type_id,
            'vehicle_make' => $profile->vehicle_make,
            'vehicle_model' => $profile->vehicle_model,
            'vehicle_year' => $profile->vehicle_year,
            'vehicle_color' => $profile->vehicle_color,
            'plate_no' => $profile->plate_no,
            'kyc_status' => $profile->kyc_status,
            'can_go_online' => (bool) ($profile->canGoOnline() ?? false),
            'grace_period_expires_at' => $profile->grace_period_expires_at?->toIso8601String(),
            'is_online' => (bool) $profile->is_online,
            'is_on_break' => (bool) $profile->is_on_break,
            'battery_saver' => (bool) $profile->battery_saver,
        ];
    }
}
