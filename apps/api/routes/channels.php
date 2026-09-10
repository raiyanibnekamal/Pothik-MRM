<?php

use App\Enums\UserRole;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('user.{id}', function ($user, $id) {
    return $user->id === $id;
});

Broadcast::channel('ride.{id}', function ($user, $id) {
    return \App\Models\Ride::where('id', $id)
        ->where(function ($q) use ($user) {
            $q->where('passenger_id', $user->id)->orWhere('driver_id', $user->id);
        })->exists();
});

Broadcast::channel('admin.ops', function ($user) {
    return UserRole::isAdmin($user->role);
});
