<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\EmergencyContactResource;
use App\Http\Resources\PublicUserResource;
use App\Models\EmergencyContact;
use App\Support\ApiResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user()->load('emergencyContacts');

        return ApiResponse::success([
            'user' => (new PublicUserResource($user))->toArray($request),
            'emergency_contacts' => EmergencyContactResource::collection($user->emergencyContacts)->toArray($request),
        ]);
    }

    public function update(Request $request)
    {
        $request->validate([
            'name' => 'sometimes|string|min:2|max:100',
            'email' => 'nullable|email|unique:users,email,' . $request->user()->id,
            'language' => 'sometimes|in:bn,en',
            'photo_url' => 'nullable|url',
        ]);

        $user = $request->user();
        $user->update($request->only(['name', 'email', 'language', 'photo_url']));

        return ApiResponse::success([
            'user' => (new PublicUserResource($user->fresh()))->toArray($request),
        ], 'Profile updated');
    }

    public function addEmergencyContact(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'phone' => 'required|string',
        ]);

        $user = $request->user();
        if ($user->emergencyContacts()->count() >= 3) {
            return ApiResponse::error('GUARDIAN_CAP', trans('You can save at most 3 emergency contacts.'), 422);
        }

        if ($user->emergencyContacts()->where('phone', $request->phone)->exists()) {
            return ApiResponse::error('DUPLICATE_GUARDIAN', trans('Duplicate guardian phone.'), 409);
        }

        app(\App\Services\OtpService::class)->validatePhone($request->phone);

        $contact = EmergencyContact::create([
            'user_id' => $user->id,
            'name' => $request->name,
            'phone' => $request->phone,
        ]);

        return ApiResponse::success(
            (new EmergencyContactResource($contact))->toArray($request),
            'Guardian added',
            201
        );
    }

    public function listEmergencyContacts(Request $request)
    {
        return ApiResponse::success(
            EmergencyContactResource::collection($request->user()->emergencyContacts)->toArray($request)
        );
    }
}