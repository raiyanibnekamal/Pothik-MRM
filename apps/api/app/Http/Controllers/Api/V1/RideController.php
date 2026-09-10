<?php

namespace App\Http\Controllers\Api\V1;

use App\Constants\ErrorCodes;
use App\Enums\RideStatus;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\Ride;
use App\Models\VehicleType;
use App\Services\DispatchService;
use App\Services\FareService;
use App\Services\PaymentService;
use App\Services\RideService;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class RideController extends Controller
{
    public function __construct(
        private RideService $rideService,
        private FareService $fareService,
        private DispatchService $dispatchService,
        private PaymentService $paymentService
    ) {}

    public function vehicleTypes()
    {
        $types = VehicleType::where('is_active', true)->get();

        return ApiResponse::success($types);
    }

    public function estimate(Request $request)
    {
        $request->validate([
            'vehicle_type_id' => 'required|exists:vehicle_types,id',
            'pickup_lat' => 'required|numeric',
            'pickup_lng' => 'required|numeric',
            'drop_lat' => 'required|numeric',
            'drop_lng' => 'required|numeric',
        ]);

        $vehicleType = VehicleType::findOrFail($request->vehicle_type_id);
        $estimate = $this->fareService->estimate(
            $vehicleType,
            (float) $request->pickup_lat,
            (float) $request->pickup_lng,
            (float) $request->drop_lat,
            (float) $request->drop_lng
        );

        return ApiResponse::success($estimate);
    }

    public function batchEstimate(Request $request)
    {
        $request->validate([
            'pickup_lat' => 'required|numeric',
            'pickup_lng' => 'required|numeric',
            'drop_lat' => 'required|numeric',
            'drop_lng' => 'required|numeric',
        ]);

        $types = VehicleType::where('is_active', true)->get();
        $quotes = $types->map(function ($type) use ($request) {
            $est = $this->fareService->estimate(
                $type,
                (float) $request->pickup_lat,
                (float) $request->pickup_lng,
                (float) $request->drop_lat,
                (float) $request->drop_lng
            );

            return [
                'vehicle_type_id' => $type->id,
                'slug' => $type->slug,
                'name_en' => $type->name_en,
                'name_bn' => $type->name_bn,
                'fare' => $est['fare'],
                'eta_min' => $est['duration_min'],
            ];
        });

        return ApiResponse::success($quotes);
    }

    public function store(Request $request)
    {
        $request->validate([
            'vehicle_type_id' => 'required|exists:vehicle_types,id',
            'pickup_lat' => 'required|numeric',
            'pickup_lng' => 'required|numeric',
            'pickup_address' => 'required|string|max:500',
            'drop_lat' => 'required|numeric',
            'drop_lng' => 'required|numeric',
            'drop_address' => 'required|string|max:500',
            'payment_method' => 'sometimes|in:cash,bkash,nagad,wallet,card',
        ]);

        $ride = $this->rideService->create($request->user(), $request->all());

        return ApiResponse::success(
            $this->rideService->formatRide($ride),
            'Ride requested',
            201
        );
    }

    public function show(Request $request, string $id)
    {
        $ride = $this->findAuthorizedRide($request, $id);
        $includePhone = in_array($ride->status, RideStatus::activeStatuses(), true);

        return ApiResponse::success($this->rideService->formatRide($ride, $includePhone));
    }

    public function index(Request $request)
    {
        $user = $request->user();
        $query = Ride::with(['vehicleType', 'driver', 'passenger']);

        if ($user->isPassenger()) {
            $query->where('passenger_id', $user->id);
        } elseif ($user->isDriver()) {
            $query->where('driver_id', $user->id);
        }

        $rides = $query->orderByDesc('created_at')->paginate(20);

        return ApiResponse::success([
            'items' => $rides->getCollection()->map(fn ($r) => $this->rideService->formatRide($r)),
            'pagination' => [
                'current_page' => $rides->currentPage(),
                'last_page' => $rides->lastPage(),
                'total' => $rides->total(),
            ],
        ]);
    }

    public function accept(Request $request, string $id)
    {
        $ride = Ride::findOrFail($id);
        $ride = $this->dispatchService->accept($ride, $request->user()->id);

        return ApiResponse::success($this->rideService->formatRide($ride));
    }

    public function decline(Request $request, string $id)
    {
        $ride = Ride::findOrFail($id);
        $this->dispatchService->decline($ride, $request->user()->id);

        return ApiResponse::success(null, 'Declined');
    }

    public function arrived(Request $request, string $id)
    {
        $ride = $this->findAuthorizedRide($request, $id);
        if ($ride->driver_id !== $request->user()->id) {
            throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        $ride = $this->rideService->transition($ride, RideStatus::DRIVER_ARRIVED, $request->user());

        return ApiResponse::success($this->rideService->formatRide($ride));
    }

    public function verifyPin(Request $request, string $id)
    {
        $request->validate(['pin' => 'required|string|size:4']);

        $ride = Ride::findOrFail($id);
        $ride = $this->rideService->verifyPin($ride, $request->pin, $request->user());

        return ApiResponse::success($this->rideService->formatRide($ride));
    }

    public function cancel(Request $request, string $id)
    {
        $request->validate(['reason' => 'nullable|string|max:200']);

        $ride = $this->findAuthorizedRide($request, $id);

        if (!RideStatus::canTransition($ride->status, RideStatus::CANCELLED)) {
            throw new ApiException(ErrorCodes::INVALID_TRANSITION, 'Cannot cancel', 409);
        }

        $ride = $this->rideService->transition($ride, RideStatus::CANCELLED, $request->user(), $request->reason);

        return ApiResponse::success($this->rideService->formatRide($ride));
    }

    public function confirmCash(Request $request, string $id)
    {
        $request->validate([
            'amount_collected' => 'required|numeric|min:0',
            'idempotency_key' => 'nullable|string|max:64',
        ]);

        $ride = Ride::findOrFail($id);
        $result = $this->paymentService->confirmCash(
            $ride,
            $request->user(),
            (float) $request->amount_collected,
            $request->idempotency_key
        );

        return ApiResponse::success([
            'transaction_id' => $result['transaction']->id,
            'commission_debt' => $result['commission_debt'] ?? null,
            'already_processed' => $result['already_processed'],
            'ride' => $this->rideService->formatRide($ride->fresh()),
        ]);
    }

    public function rate(Request $request, string $id)
    {
        $request->validate([
            'score' => 'required|integer|min:1|max:5',
            'tags' => 'nullable|array',
            'comment' => 'nullable|string|max:500',
        ]);

        $ride = Ride::findOrFail($id);
        $rating = $this->rideService->rate(
            $ride,
            $request->user(),
            $request->score,
            $request->tags,
            $request->comment
        );

        return ApiResponse::success($rating, 'Rating submitted');
    }

    public function shareLink(Request $request, string $id)
    {
        $ride = $this->findAuthorizedRide($request, $id);

        if (!$ride->share_token) {
            $ride->update(['share_token' => Str::random(48)]);
        }

        return ApiResponse::success([
            'url' => url("/public/track/{$ride->share_token}"),
            'token' => $ride->share_token,
        ]);
    }

    private function findAuthorizedRide(Request $request, string $id): Ride
    {
        $ride = Ride::find($id);
        if (!$ride) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'Ride not found', 404);
        }

        $user = $request->user();
        if ($ride->passenger_id !== $user->id && $ride->driver_id !== $user->id && !$user->isAdmin()) {
            throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        return $ride;
    }
}
