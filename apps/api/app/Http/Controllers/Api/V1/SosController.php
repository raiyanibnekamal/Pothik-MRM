<?php

namespace App\Http\Controllers\Api\V1;

use App\Constants\ErrorCodes;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\SosAlert;
use App\Services\SosService;
use App\Support\ApiResponse;
use Illuminate\Http\Request;

class SosController extends Controller
{
    public function __construct(private SosService $sosService) {}

    public function trigger(Request $request)
    {
        $request->validate([
            'ride_id' => 'nullable|uuid|exists:rides,id',
            'lat' => 'nullable|numeric|between:-90,90',
            'lng' => 'nullable|numeric|between:-180,180',
            'trigger_type' => 'nullable|in:hold,shake,power,ridecheck_deviation,ridecheck_stop,checkin_timeout,crash,admin',
        ]);

        $alert = $this->sosService->trigger($request->user(), $request->all());

        return ApiResponse::success($alert, 'SOS triggered', 201);
    }

    public function show(Request $request, string $id)
    {
        $alert = SosAlert::where('id', $id)->where('user_id', $request->user()->id)->first();
        if (!$alert) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'SOS not found', 404);
        }

        return ApiResponse::success($alert);
    }

    public function cancel(Request $request, string $id)
    {
        $alert = $this->sosService->cancel($request->user(), $id);

        return ApiResponse::success($alert, 'SOS cancelled');
    }

    public function resolve(Request $request, string $id)
    {
        $alert = $this->sosService->resolve($id, $request->user());

        return ApiResponse::success($alert, 'SOS resolved');
    }

    public function activeAlerts(Request $request)
    {
        if (!$request->user()->isAdmin()) {
            throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        $alerts = SosAlert::with(['user', 'ride'])
            ->where('status', 'active')
            ->orderByDesc('created_at')
            ->get();

        return ApiResponse::success($alerts);
    }
}
