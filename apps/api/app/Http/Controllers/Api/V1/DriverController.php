<?php

namespace App\Http\Controllers\Api\V1;

use App\Constants\ErrorCodes;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\DriverCommissionDebt;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\PlatformConfig;
use App\Services\LocationService;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class DriverController extends Controller
{
    public function onboardingStatus(Request $request)
    {
        $profile = $request->user()->driverProfile?->load('documents', 'vehicleType');

        return ApiResponse::success([
            'profile' => $profile,
            'can_go_online' => $profile?->canGoOnline() ?? false,
            'kyc_status' => $profile?->kyc_status ?? 'pending',
            'grace_expires_at' => $profile?->grace_period_expires_at?->toIso8601String(),
        ]);
    }

    public function savePersonal(Request $request)
    {
        $request->validate([
            'name' => 'required|string|min:2|max:100',
            'nid' => ['required', 'string', 'regex:/^\d{10}$|^\d{13}$|^\d{17}$/'],
            'date_of_birth' => 'required|date|before:-18 years',
            'address' => 'required|string|max:500',
        ]);

        $user = $request->user();
        $user->update(['name' => $request->name]);

        if (DriverProfile::where('nid', $request->nid)->where('user_id', '!=', $user->id)->exists()) {
            throw new ApiException(ErrorCodes::DUPLICATE_NID, trans('This NID is already registered.'), 409);
        }

        $profile = DriverProfile::updateOrCreate(
            ['user_id' => $user->id],
            [
                'nid' => $request->nid,
                'date_of_birth' => $request->date_of_birth,
                'address' => $request->address,
                'grace_period_expires_at' => now()->addHours(24),
            ]
        );

        return ApiResponse::success($profile);
    }

    public function saveVehicle(Request $request)
    {
        $request->validate([
            'vehicle_type_id' => 'required|exists:vehicle_types,id',
            'vehicle_make' => 'required|string|max:50',
            'vehicle_model' => 'required|string|max:50',
            'vehicle_year' => 'required|integer|min:2015|max:' . (date('Y') + 1),
            'vehicle_color' => 'required|string|max:30',
            'plate_no' => 'required|string|max:20',
        ]);

        $user = $request->user();

        if (DriverProfile::where('plate_no', $request->plate_no)->where('user_id', '!=', $user->id)->exists()) {
            throw new ApiException(ErrorCodes::DUPLICATE_PLATE, trans('This number plate is already registered.'), 409);
        }

        $profile = DriverProfile::updateOrCreate(
            ['user_id' => $user->id],
            $request->only([
                'vehicle_type_id', 'vehicle_make', 'vehicle_model',
                'vehicle_year', 'vehicle_color', 'plate_no',
            ])
        );

        return ApiResponse::success($profile->load('vehicleType'));
    }

    public function uploadDocument(Request $request)
    {
        $request->validate([
            'doc_type' => 'required|in:nid,license,blue_book,tax_token,fitness,profile_photo,vehicle_photo',
            'file_url' => 'required|url',
        ]);

        $profile = $request->user()->driverProfile;
        if (!$profile) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Complete personal info first', 404);
        }

        $doc = DriverDocument::updateOrCreate(
            ['driver_profile_id' => $profile->id, 'doc_type' => $request->doc_type],
            ['file_url' => $request->file_url, 'status' => 'pending', 'rejection_note' => null]
        );

        return ApiResponse::success($doc);
    }

    public function submitForReview(Request $request)
    {
        $profile = $request->user()->driverProfile;
        if (!$profile) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Profile incomplete', 404);
        }

        $profile->update(['kyc_status' => 'pending']);

        return ApiResponse::success($profile, 'Submitted for review');
    }

    public function setAvailability(Request $request)
    {
        $request->validate([
            'is_online' => 'required|boolean',
            'is_on_break' => 'sometimes|boolean',
            'battery_saver' => 'sometimes|boolean',
        ]);

        $profile = $request->user()->driverProfile;
        if (!$profile) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Driver profile required', 404);
        }

        if ($request->is_online && !$profile->canGoOnline()) {
            throw new ApiException(ErrorCodes::GRACE_OVER, trans('Submit your documents and wait for approval before going online.'), 403);
        }

        if ($request->is_online && $this->isDebtCapped($request->user()->id)) {
            throw new ApiException(ErrorCodes::DEBT_CAP, trans('Commission debt limit exceeded. You cannot go online.'), 403);
        }

        $profile->update($request->only(['is_online', 'is_on_break', 'battery_saver']));

        return ApiResponse::success($profile->fresh());
    }

    public function updateLocation(Request $request)
    {
        $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
            'speed_kmh' => 'nullable|numeric|min:0',
            'ride_id' => 'nullable|uuid|exists:rides,id',
        ]);

        $result = app(LocationService::class)->updateDriverLocation(
            $request->user()->id,
            (float) $request->lat,
            (float) $request->lng,
            $request->speed_kmh ? (float) $request->speed_kmh : null,
            $request->ride_id
        );

        return ApiResponse::success($result);
    }

    public function earnings(Request $request)
    {
        $driverId = $request->user()->id;
        $today = now()->startOfDay();

        $todayTrips = \App\Models\Ride::where('driver_id', $driverId)
            ->where('status', 'completed')
            ->where('completed_at', '>=', $today)
            ->count();

        $todayGross = \App\Models\Transaction::whereHas('ride', fn ($q) => $q->where('driver_id', $driverId))
            ->where('type', 'ride_payment')
            ->where('created_at', '>=', $today)
            ->sum('amount');

        $todayCommission = DriverCommissionDebt::where('driver_id', $driverId)
            ->where('created_at', '>=', $today)
            ->sum('amount');

        $totalDebt = DriverCommissionDebt::where('driver_id', $driverId)
            ->where('is_paid', false)
            ->sum('amount');

        return ApiResponse::success([
            'today' => [
                'trips' => $todayTrips,
                'gross' => (float) $todayGross,
                'commission' => (float) $todayCommission,
                'net' => (float) ($todayGross - $todayCommission),
            ],
            'commission_debt' => (float) $totalDebt,
        ]);
    }

    private function isDebtCapped(string $driverId): bool
    {
        $cap = (float) (PlatformConfig::get('debt_cap', ['amount' => 5000])['amount'] ?? 5000);
        $debt = DriverCommissionDebt::where('driver_id', $driverId)->where('is_paid', false)->sum('amount');

        return $debt >= $cap;
    }
}
