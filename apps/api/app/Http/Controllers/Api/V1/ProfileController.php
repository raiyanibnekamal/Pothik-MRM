<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use App\Support\ApiResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user()->load('emergencyContacts');

        return ApiResponse::success([
            'id' => $user->id,
            'phone' => $user->phone,
            'email' => $user->email,
            'name' => $user->name,
            'photo_url' => $user->photo_url,
            'role' => $user->role,
            'language' => $user->language,
            'rating_avg' => (float) $user->rating_avg,
            'emergency_contacts' => $user->emergencyContacts,
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

        return ApiResponse::success($user->fresh(), 'Profile updated');
    }

    public function addEmergencyContact(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'phone' => 'required|string',
        ]);

        $user = $request->user();
        if ($user->emergencyContacts()->count() >= 3) {
            return ApiResponse::error('GUARDIAN_CAP', 'সর্বোচ্চ ৩ জন ইমার্জেন্সি কন্টাক্ট।', 422);
        }

        if ($user->emergencyContacts()->where('phone', $request->phone)->exists()) {
            return ApiResponse::error('DUPLICATE_GUARDIAN', 'Duplicate guardian phone', 409);
        }

        app(\App\Services\OtpService::class)->validatePhone($request->phone);

        $contact = EmergencyContact::create([
            'user_id' => $user->id,
            'name' => $request->name,
            'phone' => $request->phone,
        ]);

        return ApiResponse::success($contact, 'Guardian added', 201);
    }

    public function listEmergencyContacts(Request $request)
    {
        return ApiResponse::success($request->user()->emergencyContacts);
    }
}
