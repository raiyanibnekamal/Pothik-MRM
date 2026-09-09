<?php

namespace App\Http\Controllers\Api\V1;

use App\Constants\ErrorCodes;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\PlatformConfig;
use App\Models\Ride;
use App\Models\SosAlert;
use App\Models\Transaction;
use App\Models\User;
use App\Models\VehicleType;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminController extends Controller
{
    public function dashboardStats()
    {
        $today = now()->startOfDay();

        return ApiResponse::success([
            'rides_today' => Ride::where('created_at', '>=', $today)->count(),
            'completed_today' => Ride::where('status', 'completed')->where('completed_at', '>=', $today)->count(),
            'gmv_today' => (float) Transaction::where('type', 'ride_payment')
                ->where('created_at', '>=', $today)->sum('amount'),
            'online_drivers' => DriverProfile::where('is_online', true)->count(),
            'pending_kyc' => DriverProfile::where('kyc_status', 'pending')->count(),
            'active_sos' => SosAlert::where('status', 'active')->count(),
            'cancel_rate' => $this->cancelRate(),
        ]);
    }

    public function pendingKyc()
    {
        $drivers = DriverProfile::with(['user', 'documents', 'vehicleType'])
            ->where('kyc_status', 'pending')
            ->paginate(20);

        return ApiResponse::success($drivers);
    }

    public function driverDetail(string $id)
    {
        $profile = DriverProfile::with(['user', 'documents', 'vehicleType'])
            ->where('user_id', $id)
            ->orWhere('id', $id)
            ->first();

        if (!$profile) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Driver not found', 404);
        }

        return ApiResponse::success($profile);
    }

    public function approveKyc(string $id)
    {
        $profile = DriverProfile::findOrFail($id);
        $profile->update(['kyc_status' => 'approved', 'kyc_rejection_note' => null]);

        return ApiResponse::success($profile, 'KYC approved');
    }

    public function rejectKyc(Request $request, string $id)
    {
        $request->validate(['note' => 'required|string|max:500']);
        $profile = DriverProfile::findOrFail($id);
        $profile->update(['kyc_status' => 'rejected', 'kyc_rejection_note' => $request->note]);

        return ApiResponse::success($profile, 'KYC rejected');
    }

    public function listUsers(Request $request)
    {
        $query = User::query()->whereIn('role', ['passenger', 'driver']);

        if ($request->search) {
            $term = '%'.$request->search.'%';
            $query->where(function ($q) use ($term) {
                $q->where('name', 'like', $term)->orWhere('phone', 'like', $term);
            });
        }

        if ($request->role) {
            $query->where('role', $request->role);
        }

        return ApiResponse::success(
            $query->orderByDesc('created_at')->paginate(30)
        );
    }

    public function blockUser(Request $request, string $id)
    {
        $request->validate(['blocked' => 'required|boolean']);
        $user = User::findOrFail($id);
        $user->update(['is_blocked' => $request->blocked]);

        return ApiResponse::success(['id' => $user->id, 'is_blocked' => $user->is_blocked]);
    }

    public function listRides(Request $request)
    {
        $query = Ride::with(['passenger', 'driver', 'vehicleType']);

        if ($request->status) {
            $query->where('status', $request->status);
        }

        return ApiResponse::success($query->orderByDesc('created_at')->paginate(30));
    }

    public function listDrivers(Request $request)
    {
        $query = DriverProfile::with(['user', 'vehicleType']);

        if ($request->online === 'true') {
            $query->where('is_online', true);
        }

        return ApiResponse::success($query->paginate(30));
    }

    public function updateVehicleType(Request $request, int $id)
    {
        $vehicleType = VehicleType::findOrFail($id);
        $vehicleType->update($request->validate([
            'base_fare' => 'sometimes|numeric|min:0',
            'per_km_rate' => 'sometimes|numeric|min:0',
            'per_min_rate' => 'sometimes|numeric|min:0',
            'min_fare' => 'sometimes|numeric|min:0',
            'is_active' => 'sometimes|boolean',
        ]));

        return ApiResponse::success($vehicleType);
    }

    public function getConfig()
    {
        return ApiResponse::success([
            'commission_rate' => PlatformConfig::get('commission_rate', ['rate' => 20]),
            'debt_cap' => PlatformConfig::get('debt_cap', ['amount' => 5000]),
            'holding_hours' => PlatformConfig::get('holding_hours', ['hours' => 24]),
            'min_app_version' => PlatformConfig::get('min_app_version', ['passenger' => '1.0.0', 'driver' => '1.0.0']),
            'maintenance_mode' => PlatformConfig::get('maintenance_mode', ['enabled' => false]),
        ]);
    }

    public function updateConfig(Request $request)
    {
        $data = $request->validate([
            'commission_rate' => 'sometimes|array',
            'debt_cap' => 'sometimes|array',
            'holding_hours' => 'sometimes|array',
            'min_app_version' => 'sometimes|array',
            'maintenance_mode' => 'sometimes|array',
        ]);

        foreach ($data as $key => $value) {
            PlatformConfig::set($key, $value);
        }

        return ApiResponse::success(null, 'Config updated');
    }

    public function holdingTransactions()
    {
        $txns = Transaction::with(['ride', 'user'])
            ->where('status', 'held')
            ->orderBy('release_at')
            ->paginate(30);

        return ApiResponse::success($txns);
    }

    public function liveMapSnapshot()
    {
        $drivers = DriverProfile::with('user')
            ->where('is_online', true)
            ->whereNotNull('current_lat')
            ->get()
            ->map(fn ($p) => [
                'driver_id' => $p->user_id,
                'name' => $p->user->name,
                'lat' => (float) $p->current_lat,
                'lng' => (float) $p->current_lng,
                'updated_at' => $p->location_updated_at?->toIso8601String(),
            ]);

        $activeRides = Ride::with(['passenger', 'driver'])
            ->whereIn('status', ['accepted', 'driver_arriving', 'driver_arrived', 'in_progress'])
            ->get();

        return ApiResponse::success([
            'drivers' => $drivers,
            'rides' => $activeRides,
        ]);
    }

    private function cancelRate(): float
    {
        $total = Ride::where('created_at', '>=', now()->subDays(7))->count();
        if ($total === 0) {
            return 0;
        }

        $cancelled = Ride::where('status', 'cancelled')
            ->where('created_at', '>=', now()->subDays(7))
            ->count();

        return round(($cancelled / $total) * 100, 2);
    }
}
