<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Ride extends Model
{
    use HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'passenger_id', 'driver_id', 'vehicle_type_id', 'status', 'payment_method',
        'pickup_lat', 'pickup_lng', 'pickup_address', 'drop_lat', 'drop_lng', 'drop_address',
        'estimated_distance_km', 'estimated_duration_min', 'estimated_fare',
        'locked_fare', 'final_fare', 'fare_locked_with_google', 'fare_flagged_for_ops',
        'pin', 'share_token', 'track_token', 'sos_active',
        'matched_at', 'started_at', 'completed_at', 'cancelled_at',
        'cancel_reason', 'cancelled_by',
    ];

    protected $casts = [
        'fare_locked_with_google' => 'boolean',
        'fare_flagged_for_ops' => 'boolean',
        'sos_active' => 'boolean',
        'matched_at' => 'datetime',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function passenger(): BelongsTo
    {
        return $this->belongsTo(User::class, 'passenger_id');
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function vehicleType(): BelongsTo
    {
        return $this->belongsTo(VehicleType::class);
    }

    public function dispatchAttempts(): HasMany
    {
        return $this->hasMany(RideDispatchAttempt::class);
    }

    public function sosAlert(): HasOne
    {
        return $this->hasOne(SosAlert::class)->where('status', 'active');
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(Rating::class);
    }
}
