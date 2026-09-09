<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DriverProfile extends Model
{
    use HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'user_id', 'nid', 'date_of_birth', 'address', 'vehicle_type_id',
        'vehicle_make', 'vehicle_model', 'vehicle_year', 'vehicle_color', 'plate_no',
        'vehicle_photo_url', 'kyc_status', 'kyc_rejection_note', 'grace_period_expires_at',
        'is_online', 'is_on_break', 'battery_saver', 'acceptance_rate',
        'current_lat', 'current_lng', 'location_updated_at',
    ];

    protected $casts = [
        'date_of_birth' => 'date',
        'grace_period_expires_at' => 'datetime',
        'location_updated_at' => 'datetime',
        'is_online' => 'boolean',
        'is_on_break' => 'boolean',
        'battery_saver' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function vehicleType(): BelongsTo
    {
        return $this->belongsTo(VehicleType::class);
    }

    public function documents(): HasMany
    {
        return $this->hasMany(DriverDocument::class);
    }

    public function isInGracePeriod(): bool
    {
        return $this->grace_period_expires_at && $this->grace_period_expires_at->isFuture();
    }

    public function canGoOnline(): bool
    {
        if ($this->kyc_status === 'approved') {
            return true;
        }

        return $this->isInGracePeriod();
    }
}
