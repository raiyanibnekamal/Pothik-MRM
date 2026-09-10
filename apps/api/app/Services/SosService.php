<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Constants\SocketEvents;
use App\Enums\RideStatus;
use App\Events\AdminSosAlert;
use App\Exceptions\ApiException;
use App\Models\EmergencyContact;
use App\Models\Ride;
use App\Models\SosAlert;
use App\Models\User;
use Illuminate\Support\Str;

class SosService
{
    public function trigger(User $user, array $data): SosAlert
    {
        $ride = null;
        if (!empty($data['ride_id'])) {
            $ride = Ride::find($data['ride_id']);
            if (!$ride || ($ride->passenger_id !== $user->id && $ride->driver_id !== $user->id)) {
                throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
            }
        }

        $this->assertGating($user, $ride);

        $existing = $this->findActiveAlert($user, $ride);
        if ($existing) {
            return $existing;
        }

        $lat = $data['lat'] ?? $ride?->pickup_lat;
        $lng = $data['lng'] ?? $ride?->pickup_lng;

        $alert = SosAlert::create([
            'user_id' => $user->id,
            'ride_id' => $ride?->id,
            'status' => 'active',
            'sms_status' => 'pending',
            'trigger_type' => $data['trigger_type'] ?? 'hold',
            'lat' => $lat,
            'lng' => $lng,
        ]);

        if ($ride) {
            $ride->update(['sos_active' => true]);
            if (!$ride->track_token) {
                $ride->update(['track_token' => Str::random(48)]);
            }
        }

        $this->notifyGuardians($user, $alert, $ride);
        event(new AdminSosAlert($alert));

        return $alert->fresh();
    }

    public function cancel(User $user, string $alertId): SosAlert
    {
        $alert = SosAlert::where('id', $alertId)->where('user_id', $user->id)->first();
        if (!$alert) {
            throw new ApiException(ErrorCodes::NOT_FOUND, 'SOS not found', 404);
        }

        if ($alert->status !== 'active') {
            return $alert;
        }

        $alert->update(['status' => 'cancelled']);

        if ($alert->ride_id) {
            Ride::where('id', $alert->ride_id)->update(['sos_active' => false]);
        }

        return $alert->fresh();
    }

    public function resolve(string $alertId, User $admin): SosAlert
    {
        $alert = SosAlert::findOrFail($alertId);
        $alert->update([
            'status' => 'resolved',
            'resolved_at' => now(),
            'resolved_by' => $admin->id,
        ]);

        if ($alert->ride_id) {
            Ride::where('id', $alert->ride_id)->update(['sos_active' => false]);
        }

        return $alert->fresh();
    }

    private function assertGating(User $user, ?Ride $ride): void
    {
        if ($user->isPassenger()) {
            if (!$ride || $ride->status !== RideStatus::IN_PROGRESS) {
                throw new ApiException(
                    ErrorCodes::SOS_NOT_ALLOWED,
                    'রাইড চলাকালীনই SOS ব্যবহার করা যাবে।',
                    403
                );
            }
        }

        if ($user->isDriver()) {
            $profile = $user->driverProfile;
            if (!$profile || !$profile->is_online) {
                throw new ApiException(
                    ErrorCodes::SOS_NOT_ALLOWED,
                    'অনলাইন থাকলে SOS ব্যবহার করা যাবে।',
                    403
                );
            }
        }
    }

    private function findActiveAlert(User $user, ?Ride $ride): ?SosAlert
    {
        $query = SosAlert::where('user_id', $user->id)->where('status', 'active');

        if ($ride) {
            $query->where('ride_id', $ride->id);
        }

        return $query->first();
    }

    private function notifyGuardians(User $user, SosAlert $alert, ?Ride $ride): void
    {
        $contacts = EmergencyContact::where('user_id', $user->id)->get();
        $trackUrl = $ride && $ride->track_token
            ? url("/public/track/{$ride->track_token}")
            : url('/');

        $driverName = 'Unknown';
        $plate = 'N/A';
        if ($ride && $ride->driver) {
            $driverName = $ride->driver->name ?? 'Driver';
            $plate = $ride->driver->driverProfile?->plate_no ?? 'N/A';
        }

        $message = "জরুরি সতর্কতা / EMERGENCY — {$user->name} SOS চালু করেছেন।\n"
            . "Ride: {$ride?->id} | সময়: " . now()->format('Y-m-d H:i') . "\n"
            . "ড্রাইভার: {$driverName} | গাড়ি: {$plate}\n"
            . "লাইভ লোকেশন: {$trackUrl}\n"
            . 'এখনই যোগাযোগ করুন।';

        $smsService = app(SmsService::class);
        $allSent = true;

        foreach ($contacts as $contact) {
            if (!$smsService->sendSos($contact->phone, $message)) {
                $allSent = false;
            }
        }

        $alert->update(['sms_status' => $allSent ? 'sent' : ($contacts->isEmpty() ? 'failed' : 'failed')]);
    }
}
