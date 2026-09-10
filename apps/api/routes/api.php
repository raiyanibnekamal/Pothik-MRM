<?php

use App\Http\Controllers\Api\V1\AdminController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\DriverController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\PublicTrackController;
use App\Http\Controllers\Api\V1\RideController;
use App\Http\Controllers\Api\V1\SosController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('/health', [HealthController::class, 'check']);

    Route::get('/public/track/{token}', [PublicTrackController::class, 'track']);

    // Auth
    Route::post('/auth/otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:10,1');
    Route::post('/auth/otp/verify', [AuthController::class, 'verifyOtp']);
    Route::post('/auth/refresh', [AuthController::class, 'refresh']);
    Route::post('/auth/admin/login', [AuthController::class, 'adminLogin'])->middleware('throttle:6,1');

    Route::get('/rides/vehicle-types', [RideController::class, 'vehicleTypes']);

    Route::middleware(['auth:api', 'jwt.blacklist'])->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/auth/device-token', [AuthController::class, 'registerDeviceToken']);

        // Profile
        Route::get('/profile', [ProfileController::class, 'show']);
        Route::patch('/profile', [ProfileController::class, 'update']);
        Route::get('/profile/emergency-contacts', [ProfileController::class, 'listEmergencyContacts']);
        Route::post('/profile/emergency-contacts', [ProfileController::class, 'addEmergencyContact']);

        // Rides
        Route::get('/rides/estimate', [RideController::class, 'estimate']);
        Route::get('/rides/estimate/batch', [RideController::class, 'batchEstimate']);
        Route::get('/rides', [RideController::class, 'index']);
        Route::post('/rides', [RideController::class, 'store']);
        Route::get('/rides/{id}', [RideController::class, 'show']);
        Route::post('/rides/{id}/accept', [RideController::class, 'accept'])->middleware('role:driver');
        Route::post('/rides/{id}/decline', [RideController::class, 'decline'])->middleware('role:driver');
        Route::post('/rides/{id}/arrived', [RideController::class, 'arrived'])->middleware('role:driver');
        Route::post('/rides/{id}/pin/verify', [RideController::class, 'verifyPin'])->middleware('role:driver');
        Route::post('/rides/{id}/cancel', [RideController::class, 'cancel']);
        Route::post('/rides/{id}/cash-confirm', [RideController::class, 'confirmCash'])->middleware('role:driver');
        Route::post('/rides/{id}/rate', [RideController::class, 'rate']);
        Route::get('/rides/{id}/share-link', [RideController::class, 'shareLink']);

        // Driver
        Route::prefix('driver')->middleware('role:driver')->group(function () {
            Route::get('/status', [DriverController::class, 'onboardingStatus']);
            Route::post('/personal', [DriverController::class, 'savePersonal']);
            Route::post('/vehicle', [DriverController::class, 'saveVehicle']);
            Route::post('/documents', [DriverController::class, 'uploadDocument']);
            Route::post('/submit', [DriverController::class, 'submitForReview']);
            Route::post('/availability', [DriverController::class, 'setAvailability']);
            Route::post('/location', [DriverController::class, 'updateLocation']);
            Route::get('/earnings', [DriverController::class, 'earnings']);
        });

        // SOS
        Route::post('/sos/trigger', [SosController::class, 'trigger']);
        Route::get('/sos/{id}', [SosController::class, 'show']);
        Route::post('/sos/{id}/cancel', [SosController::class, 'cancel']);

        // Admin
        Route::prefix('admin')->middleware('role:super_admin,sub_admin_finance,sub_admin_support,sub_admin_dispatch,support_agent')->group(function () {
            Route::get('/dashboard', [AdminController::class, 'dashboardStats']);
            Route::get('/live-map', [AdminController::class, 'liveMapSnapshot']);
            Route::get('/drivers', [AdminController::class, 'listDrivers']);
            Route::get('/drivers/{id}', [AdminController::class, 'driverDetail']);
            Route::get('/kyc/pending', [AdminController::class, 'pendingKyc']);
            Route::post('/kyc/{id}/approve', [AdminController::class, 'approveKyc']);
            Route::post('/kyc/{id}/reject', [AdminController::class, 'rejectKyc']);
            Route::get('/users', [AdminController::class, 'listUsers']);
            Route::post('/users/{id}/block', [AdminController::class, 'blockUser']);
            Route::get('/rides', [AdminController::class, 'listRides']);
            Route::put('/vehicle-types/{id}', [AdminController::class, 'updateVehicleType']);
            Route::get('/config', [AdminController::class, 'getConfig']);
            Route::put('/config', [AdminController::class, 'updateConfig']);
            Route::get('/holding', [AdminController::class, 'holdingTransactions']);
            Route::get('/sos/active', [SosController::class, 'activeAlerts']);
            Route::post('/sos/{id}/resolve', [SosController::class, 'resolve']);
        });
    });
});
